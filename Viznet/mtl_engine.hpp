#pragma once

#define GLFW_INCLUDE_NONE
#import <GLFW/glfw3.h>
#define GLFW_EXPOSE_NATIVE_COCOA
#import <GLFW/glfw3native.h>

#include <Metal/Metal.hpp>
#include <Metal/Metal.h>
#include <QuartzCore/CAMetalLayer.hpp>
#include <QuartzCore/CAMetalLayer.h>
#include <QuartzCore/QuartzCore.hpp>
#include "parser.h"
#include "graph_engine.hpp"
#include "camera.hpp"
#include <map>

#include <simd/simd.h>

using namespace simd;

struct Character {
    MTL::Texture* textureAtlas;  // The Metal texture containing the entire atlas
    int2 Size;  // Size of the glyph in the atlas
    int2 Bearing;  // Offset from baseline to left/top of glyph
    uint Advance;  // Horizontal offset to advance to next glyph
    float2 UV_Start;  // Starting UV coordinates in the texture atlas
    float2 UV_End;  // Ending UV coordinates in the texture atlas
};

class MTLEngine
{
public:
    void init(State* state);
    void run();
    void cleanup();
    
    Camera camera;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 projectionMatrix;

private:
    void initDevice();
    void initWindow();
    void initText();

    void createTriangle();
    void createDefaultLibrary();
    void createCommandQueue();
    void createTriangleRenderPipeline();
    void createTextRenderPipeline();
    void generateSphere(float radius, unsigned int rings, unsigned int sectors);

    void renderEntities(MTL::RenderCommandEncoder* renderCommandEncoder, std::vector<float4x4> transforms, std::vector<NodeState> selections, MTL::Buffer* vertices, MTL::Buffer* indices, int numberOfIndices);
    void encodeRenderCommand(MTL::RenderCommandEncoder *renderEncoder, State* state);
    void sendRenderCommand(State* state);

    MTL::Device *metalDevice;
    GLFWwindow *glfwWindow;
    NSWindow *metalWindow;
    CAMetalLayer *metalLayer;
    CA::MetalDrawable *metalDrawable;
    MTL::Texture* depthTexture;
    MTL::DepthStencilState* depthStencilState;
    MTL::RenderPassDescriptor* renderPassDescriptor;

    MTL::Library *metalDefaultLibrary;
    MTL::CommandQueue *metalCommandQueue;
    MTL::CommandBuffer *metalCommandBuffer;
    MTL::RenderPipelineState *metalRenderTrianglePSO;
    MTL::RenderPipelineState *metalRenderTextPSO;
    MTL::SamplerState *samplerState;
    std::vector<float3> sphereVertices;
    std::vector<uint32> sphereIndices;
    MTL::Buffer *sphereVertexBuffer;
    MTL::Buffer *sphereIndexBuffer;
    
    std::map<char, Character> Characters;
};
