// json_parser.h
#ifndef PARSER_H
#define PARSER_H

#include <string>
#include <jansson.h>

typedef struct
{
    short id;
    std::string source;
    std::vector<short> dependencies;
} Module;

std::vector<Module> load_json_file(const std::string filename);

#endif // PARSER_H
