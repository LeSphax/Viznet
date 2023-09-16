
#include <metal_stdlib>
using namespace metal;

typedef enum {
    IDLE = 0,
    SELECTED,
    SELECTED_CONNECTED
} NodeSelectionState;

struct VertexOut {
    float4 position [[position]];
    uint selectionState;
    float color;
};


vertex VertexOut vertexShader(uint vertexID [[vertex_id]],
                              constant float3* vertexPositions [[buffer(0)]],
                              constant float4x4* modelMatrices [[buffer(1)]],
                              constant float4x4& viewMatrix [[buffer(2)]],
                              constant float4x4& projectionMatrix [[buffer(3)]],
                              constant short* selectionState [[buffer(4)]],
                              uint instanceID [[instance_id]]) {

    VertexOut out;

    out.selectionState = selectionState[instanceID];

    // Model Matrix for translation
    float4x4 modelMatrix = modelMatrices[instanceID];
    float4 worldPosition = modelMatrix * float4(vertexPositions[vertexID], 1.0);
    float4 cameraPosition = viewMatrix * worldPosition;
    float4 endPos = projectionMatrix * cameraPosition;
    out.color = instanceID / 100.0f;
    out.position = float4(endPos.x, endPos.y, endPos.z, endPos.w);
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
    if (in.selectionState == SELECTED){
        return float4(0.8f, 0.1f, 0.1f , 1.0f);
    } else if (in.selectionState == SELECTED_CONNECTED){
        return float4(0.6f, 0.1f, 0.1f , 1.0f);
    }
        return float4(0.3f, 0.8f, 0.3f , 1.0f);
}
