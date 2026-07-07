#include "imageUtil.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <math.h>
#ifdef _OPENMP
#include <omp.h>
#endif

#define COARSE_SCALE 4
#define REFINE_MARGIN 12
#define MIN_COARSE_DIM 6

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

Image *downscaleImage(Image *src, int factor)
{
	int nw = src->width / factor;
	int nh = src->height / factor;
	if (nw < 1) nw = 1;
	if (nh < 1) nh = 1;
	int c = src->channel;
	int n = factor * factor;
	Image *dst = createImage(nw, nh, c);
	int x, y, ch, dy, dx;
	for (y = 0; y < nh; y++)
		for (x = 0; x < nw; x++)
			for (ch = 0; ch < c; ch++)
			{
				int sum = 0;
				for (dy = 0; dy < factor; dy++)
					for (dx = 0; dx < factor; dx++)
						sum += src->data[((y * factor + dy) * src->width + (x * factor + dx)) * c + ch];
				dst->data[(y * nw + x) * c + ch] = (unsigned char)(sum / n);
			}
	return dst;
}

Image *toGray(Image *src)
{
	if (src->channel == 1) return cloneImage(src);
	Image *g = createImage(src->width, src->height, 1);
	cvtColorGray(src, g);
	return g;
}

void matchGrayRegion(Image *src, Image *tmpl, Image *mask,
                     int y0, int y1, int x0, int x1,
                     Point *position, double *distance)
{
	int norm = tmpl->width * tmpl->height;
	if (mask)
	{
		norm = 0;
		int k;
		for (k = 0; k < tmpl->width * tmpl->height; k++)
			if (mask->data[k] > 128) norm++;
		if (norm == 0) norm = tmpl->width * tmpl->height;
	}

	int min_distance = INT_MAX;
	int ret_x = x0, ret_y = y0;
	int y, x, i, j;

	#pragma omp parallel for schedule(dynamic) private(x, i, j)
	for (y = y0; y <= y1; y++)
	{
		for (x = x0; x <= x1; x++)
		{
			int d = 0;
			for (j = 0; j < tmpl->height; j++)
			{
				for (i = 0; i < tmpl->width; i++)
				{
					if (mask && mask->data[j * tmpl->width + i] <= 128)
						continue;
					int v = src->data[(y + j) * src->width + (x + i)] - tmpl->data[j * tmpl->width + i];
					d += v * v;
				}
				if (d >= min_distance) break;
			}
			if (d < min_distance)
			{
				#pragma omp critical
				{
					if (d < min_distance)
					{
						min_distance = d;
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

void matchMultiRes(Image *src_gray, Image *src_coarse,
                   Image *tmpl_gray, Image *mask, double threshold,
                   Point *position, double *distance)
{
	int full_y = src_gray->height - tmpl_gray->height;
	int full_x = src_gray->width - tmpl_gray->width;
	if (full_y < 0 || full_x < 0)
	{
		position->x = 0;
		position->y = 0;
		*distance = 1e30;
		return;
	}

	int tw_c = tmpl_gray->width / COARSE_SCALE;
	int th_c = tmpl_gray->height / COARSE_SCALE;

	if (tw_c >= MIN_COARSE_DIM && th_c >= MIN_COARSE_DIM && src_coarse)
	{
		Image *tmpl_c = downscaleImage(tmpl_gray, COARSE_SCALE);
		Image *mask_c = mask ? downscaleImage(mask, COARSE_SCALE) : NULL;

		int cy1 = src_coarse->height - tmpl_c->height;
		int cx1 = src_coarse->width - tmpl_c->width;

		if (cy1 >= 0 && cx1 >= 0)
		{
			Point cp;
			double cd;
			matchGrayRegion(src_coarse, tmpl_c, mask_c, 0, cy1, 0, cx1, &cp, &cd);

			freeImage(tmpl_c);
			if (mask_c) freeImage(mask_c);

			int fy = cp.y * COARSE_SCALE;
			int fx = cp.x * COARSE_SCALE;
			int ry0 = fy - REFINE_MARGIN; if (ry0 < 0) ry0 = 0;
			int rx0 = fx - REFINE_MARGIN; if (rx0 < 0) rx0 = 0;
			int ry1 = fy + REFINE_MARGIN; if (ry1 > full_y) ry1 = full_y;
			int rx1 = fx + REFINE_MARGIN; if (rx1 > full_x) rx1 = full_x;

			matchGrayRegion(src_gray, tmpl_gray, mask, ry0, ry1, rx0, rx1, position, distance);

			if (*distance < threshold)
				return;
		}
		else
		{
			freeImage(tmpl_c);
			if (mask_c) freeImage(mask_c);
		}
	}

	matchGrayRegion(src_gray, tmpl_gray, mask, 0, full_y, 0, full_x, position, distance);
}

void processOneTemplate(Image *src_gray, Image *src_coarse, Image *src_color,
                        const char *template_file, int rotation, const char *mask_file,
                        double threshold, int isRotate, int isScale, int isPrint, int isWrite,
                        const char *output_name_txt)
{
	Image *tmpl = readPXM(template_file);
	if (!tmpl) return;

	Image *mask = NULL;
	if (mask_file && mask_file[0])
	{
		mask = readPXM(mask_file);
		if (mask && mask->channel == 3)
		{
			Image *mg = createImage(mask->width, mask->height, 1);
			cvtColorGray(mask, mg);
			freeImage(mask);
			mask = mg;
		}
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
	int bestW = tmpl->width;
	int bestH = tmpl->height;

	int si, ri;
	for (si = 0; si < nScales; si++)
	{
		double sf = scaleFactors[si];
		Image *scaledT = (sf == 1.0) ? tmpl : scaleImage(tmpl, sf);
		Image *scaledM = (sf == 1.0 || !mask) ? mask : scaleImage(mask, sf);

		for (ri = 0; ri < nRots; ri++)
		{
			int ra = rotAngles[ri];
			Image *rotT = (ra == 0) ? scaledT : rotateImage(scaledT, ra);
			Image *rotM = (ra == 0 || !scaledM) ? scaledM : rotateImage(scaledM, ra);

			if (rotT->width >= src_gray->width || rotT->height >= src_gray->height)
			{
				if (ra != 0) { freeImage(rotT); if (rotM && rotM != scaledM) freeImage(rotM); }
				continue;
			}

			Image *tg = toGray(rotT);
			Image *mg = (rotM && rotM->channel != 1) ? toGray(rotM) : rotM;

			Point pos;
			double dist;
			matchMultiRes(src_gray, src_coarse, tg, mg, threshold, &pos, &dist);

			if (tg != rotT) freeImage(tg);
			if (mg && mg != rotM) freeImage(mg);

			if (dist < bestDist)
			{
				bestDist = dist;
				bestPos = pos;
				bestRot = ra;
				bestW = rotT->width;
				bestH = rotT->height;
			}

			if (ra != 0) { freeImage(rotT); if (rotM && rotM != scaledM) freeImage(rotM); }
			if (bestDist <= 0.0) break;
		}

		if (sf != 1.0) { freeImage(scaledT); if (scaledM && scaledM != mask) freeImage(scaledM); }
		if (bestDist <= 0.0) break;
	}

	printf("rotation -> %d\n", bestRot);
	if (bestDist < threshold)
	{
		writeResult(output_name_txt, getBaseName(template_file), bestPos, bestW, bestH, bestRot, bestDist);
		if (isPrint)
			printf("[Found    ] %s %d %d %d %d %d %f\n", getBaseName(template_file), bestPos.x, bestPos.y, bestW, bestH, bestRot, bestDist);
		if (isWrite && src_color)
		{
			char output_name_img[256];
			strcpy(output_name_img, "result/");
			strcat(output_name_img, getBaseName(template_file));
			drawRectangle(src_color, bestPos, bestW, bestH);
			if (src_color->channel == 3)
				strcat(output_name_img, ".ppm");
			else
				strcat(output_name_img, ".pgm");
			writePXM(output_name_img, src_color);
		}
	}
	else
	{
		if (isPrint)
			printf("[Not found] %s %d %d %d %d %d %f\n", getBaseName(template_file), bestPos.x, bestPos.y, bestW, bestH, bestRot, bestDist);
	}

	freeImage(tmpl);
	if (mask) freeImage(mask);
}

int main(int argc, char **argv)
{
	if (argc < 3)
	{
		fprintf(stderr, "Usage: matching src template rotation threshold options [mask]\n");
		fprintf(stderr, "  or:  matching src --batch batch_file threshold options\n");
		return -1;
	}

	char *input_file = argv[1];

	char output_name_txt[256];
	strcpy(output_name_txt, "result/");
	strcat(output_name_txt, getBaseName(input_file));
	strcat(output_name_txt, ".txt");

	Image *img = readPXM(input_file);
	if (!img) return -1;

	Image *img_gray = toGray(img);
	Image *img_coarse = downscaleImage(img_gray, COARSE_SCALE);

	if (strcmp(argv[2], "--batch") == 0)
	{
		if (argc < 5)
		{
			fprintf(stderr, "Batch usage: matching src --batch batch_file threshold [options]\n");
			freeImage(img); freeImage(img_gray); freeImage(img_coarse);
			return -1;
		}

		char *batch_file = argv[3];
		double threshold = atof(argv[4]);
		char *options = argc >= 6 ? argv[5] : "";

		int isRotate = 0, isScale = 0, isPrint = 0, isWrite = 0;
		if (strchr(options, 'c')) clearResult(output_name_txt);
		if (strchr(options, 'r')) isRotate = 1;
		if (strchr(options, 's')) isScale = 1;
		if (strchr(options, 'p')) isPrint = 1;
		if (strchr(options, 'w')) isWrite = 1;

		FILE *fp = fopen(batch_file, "r");
		if (!fp)
		{
			fprintf(stderr, "Cannot open batch file: %s\n", batch_file);
			freeImage(img); freeImage(img_gray); freeImage(img_coarse);
			return -1;
		}

		char line[1024];
		while (fgets(line, sizeof(line), fp))
		{
			char tmpl_path[512] = "";
			char mask_path[512] = "";
			int rotation = 0;
			int n = sscanf(line, "%511s %d %511s", tmpl_path, &rotation, mask_path);
			if (n < 2 || tmpl_path[0] == '\0') continue;

			processOneTemplate(img_gray, img_coarse, img,
			                   tmpl_path, rotation, n >= 3 ? mask_path : NULL,
			                   threshold, isRotate, isScale, isPrint, isWrite,
			                   output_name_txt);
		}

		fclose(fp);
	}
	else
	{
		if (argc < 5)
		{
			fprintf(stderr, "Usage: matching src template rotation threshold options [mask]\n");
			freeImage(img); freeImage(img_gray); freeImage(img_coarse);
			return -1;
		}

		char *template_file = argv[2];
		int rotation = atoi(argv[3]);
		double threshold = atof(argv[4]);
		char *options = argc >= 6 ? argv[5] : "";
		char *mask_file = argc >= 7 ? argv[6] : NULL;

		int isRotate = 0, isScale = 0, isPrint = 0, isWrite = 0;
		if (strchr(options, 'c')) clearResult(output_name_txt);
		if (strchr(options, 'r')) isRotate = 1;
		if (strchr(options, 's')) isScale = 1;
		if (strchr(options, 'p')) isPrint = 1;
		if (strchr(options, 'w')) isWrite = 1;

		processOneTemplate(img_gray, img_coarse, img,
		                   template_file, rotation, mask_file,
		                   threshold, isRotate, isScale, isPrint, isWrite,
		                   output_name_txt);
	}

	freeImage(img);
	freeImage(img_gray);
	freeImage(img_coarse);
	return 0;
}
