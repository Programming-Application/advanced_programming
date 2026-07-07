#include "imageUtil.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <math.h>
#ifdef _OPENMP
#include <omp.h>
#endif

Image *rotateImage(Image *src, int angle)
{
	int W = src->width, H = src->height, c = src->channel;
	Image *dst;
	int x, y, ch;

	if (angle == 90)
	{
		dst = createImage(H, W, c);
		for (y = 0; y < H; y++)
			for (x = 0; x < W; x++)
				for (ch = 0; ch < c; ch++)
					dst->data[(x * H + (H - 1 - y)) * c + ch] = src->data[(y * W + x) * c + ch];
	}
	else if (angle == 180)
	{
		dst = createImage(W, H, c);
		for (y = 0; y < H; y++)
			for (x = 0; x < W; x++)
				for (ch = 0; ch < c; ch++)
					dst->data[((H - 1 - y) * W + (W - 1 - x)) * c + ch] = src->data[(y * W + x) * c + ch];
	}
	else if (angle == 270)
	{
		dst = createImage(H, W, c);
		for (y = 0; y < H; y++)
			for (x = 0; x < W; x++)
				for (ch = 0; ch < c; ch++)
					dst->data[((W - 1 - x) * H + y) * c + ch] = src->data[(y * W + x) * c + ch];
	}
	else
	{
		return cloneImage(src);
	}
	return dst;
}

Image *scaleImage(Image *src, double factor)
{
	int newW = (int)(src->width * factor + 0.5);
	int newH = (int)(src->height * factor + 0.5);
	if (newW < 1) newW = 1;
	if (newH < 1) newH = 1;
	int c = src->channel;
	Image *dst = createImage(newW, newH, c);
	int x, y, ch;
	for (y = 0; y < newH; y++)
		for (x = 0; x < newW; x++)
		{
			double sx = (x + 0.5) / factor - 0.5;
			double sy = (y + 0.5) / factor - 0.5;
			int x0 = (int)sx;
			int y0 = (int)sy;
			if (sx < 0) { x0 = 0; sx = 0; }
			if (sy < 0) { y0 = 0; sy = 0; }
			int x1 = x0 + 1;
			int y1 = y0 + 1;
			if (x1 >= src->width) x1 = src->width - 1;
			if (y1 >= src->height) y1 = src->height - 1;
			double fx = sx - x0;
			double fy = sy - y0;
			for (ch = 0; ch < c; ch++)
			{
				double v00 = src->data[(y0 * src->width + x0) * c + ch];
				double v10 = src->data[(y0 * src->width + x1) * c + ch];
				double v01 = src->data[(y1 * src->width + x0) * c + ch];
				double v11 = src->data[(y1 * src->width + x1) * c + ch];
				double val = v00 * (1 - fx) * (1 - fy) + v10 * fx * (1 - fy) +
				             v01 * (1 - fx) * fy + v11 * fx * fy;
				int iv = (int)(val + 0.5);
				if (iv > 255) iv = 255;
				dst->data[(y * newW + x) * c + ch] = (unsigned char)iv;
			}
		}
	return dst;
}

void templateMatchingGray(Image *src, Image *template, Image *mask, Point *position, double *distance)
{
	if (src->channel != 1 || template->channel != 1)
	{
		fprintf(stderr, "src and/or templeta image is not a gray image.\n");
		return;
	}

	int norm = template->width * template->height;
	if (mask)
	{
		norm = 0;
		int k;
		for (k = 0; k < template->width * template->height; k++)
			if (mask->data[k] > 128) norm++;
		if (norm == 0) norm = template->width * template->height;
	}

	int min_distance = INT_MAX;
	int ret_x = 0;
	int ret_y = 0;
	int x, y, i, j;
	#pragma omp parallel for schedule(dynamic) private(x, i, j)
	for (y = 0; y < (src->height - template->height); y++)
	{
		for (x = 0; x < src->width - template->width; x++)
		{
			int distance = 0;
			for (j = 0; j < template->height; j++)
			{
				for (i = 0; i < template->width; i++)
				{
					if (mask && mask->data[j * template->width + i] <= 128)
						continue;
					int v = (src->data[(y + j) * src->width + (x + i)] - template->data[j * template->width + i]);
					distance += v * v;
				}
				if (distance >= min_distance)
					break;
			}
			if (distance < min_distance)
			{
				#pragma omp critical
				{
					if (distance < min_distance)
					{
						min_distance = distance;
						ret_x = x;
						ret_y = y;
					}
				}
			}
		}
	}

	position->x = ret_x;
	position->y = ret_y;
	*distance = sqrt((double)min_distance / norm);
}

void templateMatchingColor(Image *src, Image *template, Image *mask, Point *position, double *distance)
{
	if (src->channel != 3 || template->channel != 3)
	{
		fprintf(stderr, "src and/or templeta image is not a color image.\n");
		return;
	}

	int norm = template->width * template->height;
	if (mask)
	{
		norm = 0;
		int k;
		for (k = 0; k < template->width * template->height; k++)
			if (mask->data[k] > 128) norm++;
		if (norm == 0) norm = template->width * template->height;
	}

	int min_distance = INT_MAX;
	int ret_x = 0;
	int ret_y = 0;
	int x, y, i, j;
	#pragma omp parallel for schedule(dynamic) private(x, i, j)
	for (y = 0; y < (src->height - template->height); y++)
	{
		for (x = 0; x < src->width - template->width; x++)
		{
			int distance = 0;
			for (j = 0; j < template->height; j++)
			{
				for (i = 0; i < template->width; i++)
				{
					if (mask && mask->data[j * template->width + i] <= 128)
						continue;
					int pt = 3 * ((y + j) * src->width + (x + i));
					int pt2 = 3 * (j * template->width + i);
					int r = (src->data[pt + 0] - template->data[pt2 + 0]);
					int g = (src->data[pt + 1] - template->data[pt2 + 1]);
					int b = (src->data[pt + 2] - template->data[pt2 + 2]);

					distance += (r * r + g * g + b * b);
				}
				if (distance >= min_distance)
					break;
			}
			if (distance < min_distance)
			{
				#pragma omp critical
				{
					if (distance < min_distance)
					{
						min_distance = distance;
						ret_x = x;
						ret_y = y;
					}
				}
			}
		}
	}

	position->x = ret_x;
	position->y = ret_y;
	*distance = sqrt((double)min_distance / norm);
}

int main(int argc, char **argv)
{
	if (argc < 5)
	{
		fprintf(stderr, "Usage: templateMatching src_image temlate_image rotation threshold option(c,w,p,g,r,s)\n");
		fprintf(stderr, "Option:\nc) clear a txt result. \nw) write result a image with rectangle.\np) print results.\ng) grayscale matching.\nr) try all rotations (0,90,180,270).\ns) try all scales (0.5,1,2).\n");
		return -1;
	}

	char *input_file = argv[1];
	char *template_file = argv[2];
	int rotation = atoi(argv[3]);
	double threshold = atof(argv[4]);

	printf("rotation -> %d\n", rotation);

	char output_name_base[256];
	char output_name_txt[256];
	char output_name_img[256];
	strcpy(output_name_base, "result/");
	strcat(output_name_base, getBaseName(input_file));
	strcpy(output_name_txt, output_name_base);
	strcat(output_name_txt, ".txt");
	strcpy(output_name_img, output_name_base);

	int isWriteImageResult = 0;
	int isPrintResult = 0;
	int isGray = 0;
	int isRotate = 0;
	int isScale = 0;

	if (argc >= 6)
	{
		char *p = NULL;
		if ((p = strchr(argv[5], 'c')) != NULL)
			clearResult(output_name_txt);
		if ((p = strchr(argv[5], 'w')) != NULL)
			isWriteImageResult = 1;
		if ((p = strchr(argv[5], 'p')) != NULL)
			isPrintResult = 1;
		if ((p = strchr(argv[5], 'g')) != NULL)
			isGray = 1;
		if ((p = strchr(argv[5], 'r')) != NULL)
			isRotate = 1;
		if ((p = strchr(argv[5], 's')) != NULL)
			isScale = 1;
	}

	Image *img = readPXM(input_file);
	Image *template = readPXM(template_file);
	if (img == NULL || template == NULL)
	{
		return -1;
	}

	Image *mask = NULL;
	if (argc >= 7)
	{
		mask = readPXM(argv[6]);
		if (mask && mask->channel == 3)
		{
			Image *mask_gray = createImage(mask->width, mask->height, 1);
			cvtColorGray(mask, mask_gray);
			freeImage(mask);
			mask = mask_gray;
		}
	}

	Image *img_gray = NULL;
	if (isGray && img->channel == 3)
	{
		img_gray = createImage(img->width, img->height, 1);
		cvtColorGray(img, img_gray);
	}

	double scaleFactors[3];
	int nScales;
	if (isScale)
	{
		scaleFactors[0] = 0.5; scaleFactors[1] = 1.0; scaleFactors[2] = 2.0;
		nScales = 3;
	}
	else
	{
		scaleFactors[0] = 1.0;
		nScales = 1;
	}

	int rotAngles[4];
	int nRots;
	if (isRotate)
	{
		rotAngles[0] = 0; rotAngles[1] = 90; rotAngles[2] = 180; rotAngles[3] = 270;
		nRots = 4;
	}
	else
	{
		rotAngles[0] = 0;
		nRots = 1;
	}

	double bestDist = 1e30;
	Point bestPos = {0, 0};
	int bestRot = rotation;
	int bestW = template->width;
	int bestH = template->height;

	int si, ri;
	for (si = 0; si < nScales; si++)
	{
		double sf = scaleFactors[si];
		Image *scaledT = (sf == 1.0) ? template : scaleImage(template, sf);
		Image *scaledM = (sf == 1.0 || !mask) ? mask : scaleImage(mask, sf);

		for (ri = 0; ri < nRots; ri++)
		{
			int ra = rotAngles[ri];
			Image *rotT = (ra == 0) ? scaledT : rotateImage(scaledT, ra);
			Image *rotM = (ra == 0 || !scaledM) ? scaledM : rotateImage(scaledM, ra);

			if (rotT->width >= img->width || rotT->height >= img->height)
			{
				if (ra != 0) { freeImage(rotT); if (rotM && rotM != scaledM) freeImage(rotM); }
				continue;
			}

			Point pos;
			double dist;

			if (img_gray)
			{
				Image *tg = createImage(rotT->width, rotT->height, 1);
				cvtColorGray(rotT, tg);
				templateMatchingGray(img_gray, tg, rotM, &pos, &dist);
				freeImage(tg);
			}
			else
			{
				templateMatchingColor(img, rotT, rotM, &pos, &dist);
			}

			if (dist < bestDist)
			{
				bestDist = dist;
				bestPos = pos;
				bestRot = ra;
				bestW = rotT->width;
				bestH = rotT->height;
			}

			if (ra != 0)
			{
				freeImage(rotT);
				if (rotM && rotM != scaledM) freeImage(rotM);
			}
		}

		if (sf != 1.0)
		{
			freeImage(scaledT);
			if (scaledM && scaledM != mask) freeImage(scaledM);
		}
	}

	if (bestDist < threshold)
	{
		writeResult(output_name_txt, getBaseName(template_file), bestPos, bestW, bestH, bestRot, bestDist);
		if (isPrintResult)
		{
			printf("[Found    ] %s %d %d %d %d %d %f\n", getBaseName(template_file), bestPos.x, bestPos.y, bestW, bestH, bestRot, bestDist);
		}
		if (isWriteImageResult)
		{
			drawRectangle(img, bestPos, bestW, bestH);

			if (img->channel == 3)
				strcat(output_name_img, ".ppm");
			else if (img->channel == 1)
				strcat(output_name_img, ".pgm");
			printf("out: %s", output_name_img);
			writePXM(output_name_img, img);
		}
	}
	else
	{
		if (isPrintResult)
		{
			printf("[Not found] %s %d %d %d %d %d %f\n", getBaseName(template_file), bestPos.x, bestPos.y, bestW, bestH, bestRot, bestDist);
		}
	}

	freeImage(img);
	freeImage(template);
	if (mask) freeImage(mask);
	if (img_gray) freeImage(img_gray);

	return 0;
}
