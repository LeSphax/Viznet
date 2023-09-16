//
//  text.metal
//  Viznet
//
//  Created by Sebastien Kerbrat on 9/3/23.
//

#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoords;
};

vertex VertexOut textVertexShader(constant float4* vertexPositions[[buffer(0)]],
                                  constant float4x4* offsets [[buffer(1)]],
                          uint vertex_id [[vertex_id]],
                          uint instanceID [[instance_id]],
                          constant float4x4& viewMatrix [[buffer(2)]],
                          constant float4x4& projectionMatrix [[buffer(3)]],
                          constant float2* uvCoordinates[[buffer(4)]]
                          )
{
    VertexOut out;
    float4x4 modelMatrix = offsets[instanceID];    
    float4 position = vertexPositions[vertex_id];
    out.texCoords = uvCoordinates[instanceID * 4 + vertex_id];
    out.position = projectionMatrix * viewMatrix * modelMatrix * position;
    return out;
}


fragment float4 textFragmentShader(VertexOut in [[stage_in]],
                              texture2d<uint> text [[texture(0)]],
                              sampler smp [[sampler(0)]])
{
    uint4 sampled = text.sample(smp, in.texCoords);
    return float4(1.0f - sampled.r, 1.0f- sampled.r , 1.0f- sampled.r, 1.0f);
}
