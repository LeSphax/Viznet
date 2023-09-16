#include <iostream>
#include <stdio.h>
#include <jansson.h>
#include <unordered_map>
#include <string>
#include "parser.h"
#include <cstdlib>

std::vector<Module> load_json_file(const std::string path)
{
    json_error_t error;
    json_t *root = json_load_file(path.c_str(), 0, &error);

    if (!root)
    {
        fprintf(stderr, "error: on line %d: %s\n", error.line, error.text);
        exit(1);
    }

    if (!json_is_array(root))
    {
        fprintf(stderr, "error: root is not an array\n");
        json_decref(root);
        exit(1);
    }

    uint numModules = json_array_size(root);
    auto modules = std::vector<Module>(numModules);

    // Create a hash map for source names to ids
    std::unordered_map<std::string, short> source_to_id;

    // First pass to fill in the source and id, and build the source to id map
    for (short i = 0; i < numModules; ++i)
    {
        json_t *module_json, *source;
        module_json = json_array_get(root, i);

        source = json_object_get(module_json, "source");
        if (!json_is_string(source))
        {
            fprintf(stderr, "error: module %d source is not a string\n", i + 1);
            json_decref(root);
            exit(1);
        }

        modules[i].id = i;
        modules[i].source = strdup(json_string_value(source));
        std::cout << modules[i].source << std::endl;
        source_to_id[modules[i].source] = i;
    }

    // Second pass to fill in the dependencies
    for (short i = 0; i < numModules; ++i)
    {
        json_t *module_json, *dependencies;
        module_json = json_array_get(root, i);

        dependencies = json_object_get(module_json, "dependencies");
        if (!json_is_array(dependencies))
        {
            fprintf(stderr, "error: module %d dependencies is not an array\n", i + 1);
            json_decref(root);
            exit(1);
        }

        modules[i].dependencies = std::vector<short>(json_array_size(dependencies));
        for (short j = 0; j < modules[i].dependencies.size(); ++j)
        {
            json_t *dependency = json_array_get(dependencies, j);
            if (!json_is_string(dependency))
            {
                fprintf(stderr, "error: module %d dependency %d is not a string\n", i + 1, j + 1);
                json_decref(root);
                exit(1);
            }

            // Lookup the id corresponding to the source name from the map
            std::string dependency_key = json_string_value(dependency);
            if (source_to_id.find(dependency_key) == source_to_id.end())
            {
                std::cerr << "error: could not find module for source name " << dependency_key << "\n";
            }
            else
            {
                modules[i].dependencies[j] = source_to_id[dependency_key];
            }
        }
    }

    json_decref(root);

    return modules;
}
