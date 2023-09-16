
#pragma once

#include <vector>
#include <simd/simd.h>
#include "parser.h"

typedef struct
{
    simd::float3 node1;
    simd::float3 node2;
} Edge;

enum NodeSelectionState: short {
    IDLE,
    SELECTED,
    SELECTED_CONNECTED
};

typedef struct {
    NodeSelectionState selection;
} NodeState;

typedef struct {
    std::vector<simd::float4x4> nodes;
    std::vector<NodeState> nodeStates;
    std::vector<Module> modules;
    std::vector<Edge> edges;
} State;

void initNodes(State* state);
void update(State* state);
