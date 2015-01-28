#ifndef MADFUNCTIONS_H_INC
#define MADFUNCTIONS_H_INC

#include <mad.h>

enum mad_flow read_from_mmap(void *data, struct mad_stream *stream);

enum mad_flow read_header(void *data, struct mad_header const * header);

enum mad_flow output(void *data,
                     struct mad_header const *header,
                     struct mad_pcm *pcm);

#endif
