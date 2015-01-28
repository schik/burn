#include <unistd.h>
#include <sys/mman.h>
#include <stdio.h>
#include <limits.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>

#include "PlayBuffer.h"

unsigned long current_frame=0;

enum mad_flow read_from_mmap(void *data, struct mad_stream *stream)
{
    PlayBuffer *playbuf = (PlayBuffer *)data;
    return [playbuf readFromMmap: stream];
}

char * layerstring(enum mad_layer layer)
{
    switch(layer)
    {
        case MAD_LAYER_I:
            return "I";
        case MAD_LAYER_II:
            return "II";
        case MAD_LAYER_III:
            return "III";
        default:
            return "?";
    }
}
    
char * modestring(enum mad_mode mode)
{
    switch(mode)
    {
        case MAD_MODE_SINGLE_CHANNEL:
            return "mono";
        case MAD_MODE_DUAL_CHANNEL:
            return "dual-channel";
        case MAD_MODE_JOINT_STEREO:
            return "joint-stereo";
        case MAD_MODE_STEREO:
            return "stereo";
        default:
            return "?";
    }
}

char * modestringucase(enum mad_mode mode)
{
    switch(mode)
    {
        case MAD_MODE_SINGLE_CHANNEL:
            return "Single-Channel";
        case MAD_MODE_DUAL_CHANNEL:
            return "Dual-Channel";
        case MAD_MODE_JOINT_STEREO:
            return "Joint-Stereo";
        case MAD_MODE_STEREO:
            return "Stereo";
        default:
            return "?";
    }
}

enum mad_flow read_header(void *data, struct mad_header const * header)
{
    PlayBuffer *playbuf = (PlayBuffer *)data;
    return [playbuf readHeader: header];
}        


enum mad_flow output(void *data,
                     struct mad_header const *header,
                     struct mad_pcm *pcm)
{
    PlayBuffer *playbuf = (PlayBuffer *)data;
    return [playbuf writeOutput: header pcmData: pcm];
}
