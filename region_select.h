#ifndef REGION_SELECT_H
#define REGION_SELECT_H

struct Region {
    int x;
    int y;
    int width;
    int height;
};

struct Region select_region();

#endif // REGION_SELECT_H
