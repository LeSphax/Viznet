#include "parser.h"
#include <simd/simd.h>
#include "graph_engine.hpp"

using namespace simd;

void buildEdges(State* state) {
    state->edges.clear(); // clear the previous edges
    for (const auto& module : state->modules) {
        for (const auto& dependency : module.dependencies) {
            Edge edge;
            edge.node1 = state->nodes[module.id].columns[3].xyz;     // Assuming the id is the index in the nodes vector
            edge.node2 = state->nodes[dependency].columns[3].xyz;    // Assuming the dependency is also an id/index
            state->edges.push_back(edge);
        }
    }
}

void calculateForces(State* state)
{
  float idealDistance = 0.2f;
  float speed = 0.05f;
  std::vector<float3> forces;
  auto& nodes = state->nodes;

  for (int i = 0; i < state->modules.size(); i++)
  {
    float rootDist = sqrt(nodes[i].columns[3].x * nodes[i].columns[3].x + nodes[i].columns[3].y * nodes[i].columns[3].y + nodes[i].columns[3].z * nodes[i].columns[3].z);
    float power = fmin(rootDist * rootDist / idealDistance, rootDist * idealDistance);
    forces.push_back(-nodes[i].columns[3].xyz / rootDist * power * speed);
      
      if (state->nodeStates[i].selection == SELECTED) {
          float3 dir = (float3){0.0f, 0.0f, -8.0f} - nodes[i].columns[3].xyz;
          float dist = sqrt(nodes[i].columns[3].x * nodes[i].columns[3].x + nodes[i].columns[3].y * nodes[i].columns[3].y + nodes[i].columns[3].z * nodes[i].columns[3].z);
          float power = fmin(dist * dist / idealDistance, dist * idealDistance);
          forces[i] += dir / dist * power * speed * 10;
      }

    for (int j = 0; j < state->modules.size(); j++)
    {
      if (i == j || state->nodeStates[i].selection == SELECTED)
        continue;

      float3 dir = nodes[j].columns[3].xyz - nodes[i].columns[3].xyz;

      float dist = sqrt(dir.x * dir.x + dir.y * dir.y + dir.z * dir.z);
      if (dist < 0.000001f)
        continue;

      int attraction = 0;
      for (int k = 0; k < state->modules[i].dependencies.size(); k++)
      {
        if (state->modules[i].dependencies[k] == j)
        {
          attraction = 1;
          break;
        }
      }
      float attractPower = fmin(attraction * dist * dist / idealDistance, dist * idealDistance);
      float repulsePower = fmin(idealDistance * idealDistance / (dist * dist), dist * idealDistance);
      float power = attractPower - repulsePower;

        float3 force = dir / dist * power * speed;
        if (state->nodeStates[j].selection == SELECTED) {
            force = (float3){force.x, force.y, force.z * 10.0f};
        }
      
      forces[i] += force;
    }
  }
    

  for (int i = 0; i < state->modules.size(); i++)
  {
    nodes[i].columns[3].xyz += forces[i];
  }
    
  
}

void initNodes(State* state)
{
    int i;
    for (i = 0; i < state->modules.size(); i++)
    {
      float4x4 node = float4x4(1.0f);
      node.columns[3].x = (float)rand() / (float)RAND_MAX * 2 - 1;
      node.columns[3].y = (float)rand() / (float)RAND_MAX * 2 - 1;
      node.columns[3].z = (float)rand() / (float)RAND_MAX * 2 - 1;
      state->nodes.push_back(node);
        state->nodeStates.push_back({IDLE});
    }
    for (i = 0; i < 10; i++) {
        calculateForces(state);
    }
}


void update(State* state)
{
  calculateForces(state);
  buildEdges(state);
}


