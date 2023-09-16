#include "mtl_engine.hpp"
#include <map>
#include <math.h>
#include <iostream>
#include "graph_engine.hpp"
#include "AAPLMathUtilities.h"
#include "camera.hpp"
#include "ft2build.h"
#include FT_FREETYPE_H

using namespace simd;


//float3 targetPosition = {0.0, 0.0, -1.0};
//float3 cameraPosition = {0.0, 0.0, 5.0};
double xOrigin = -1.0f;
double yOrigin = -1.0f;
int HEIGHT = 600;
int WIDTH = 800;

std::map<GLFWwindow *, MTLEngine *> engines;
State* state;
std::vector<float2> uvCoordinates;

struct TextureSize {
    int width;
    int height;
    int maxGlyphWidth;
    int maxGlyphHeight;
};

TextureSize getTextureSize(FT_Face face, int numRows, int numCols) {
    TextureSize size;
    size.maxGlyphWidth = 0;
    size.maxGlyphHeight = 0;

    // Iterate through characters to find max width and height
    for (unsigned char c = 0; c < numRows * numCols; c++) {
        if (FT_Load_Char(face, c, FT_LOAD_RENDER)) {
            std::cout << "ERROR::FREETYPE: Failed to load Glyph" << std::endl;
            continue;
        }
        size.maxGlyphWidth = std::max(size.maxGlyphWidth, (int)face->glyph->bitmap.width);
        size.maxGlyphHeight = std::max(size.maxGlyphHeight, (int)face->glyph->bitmap.rows);
    }

    // Calculate the size of the texture atlas
    size.width = size.maxGlyphWidth * numCols;
    size.height = size.maxGlyphHeight * numRows;
    return size;
}

void MTLEngine::initText() {
    FT_Library ft;
    if (FT_Init_FreeType(&ft))
    {
        std::cout << "ERROR::FREETYPE: Could not init FreeType Library" << std::endl;
        return;
    }

    FT_Face face;
    if (FT_New_Face(ft, "data/arial.ttf", 0, &face))
    {
        std::cout << "ERROR::FREETYPE: Failed to load font" << std::endl;
        return;
    }
    
    FT_Set_Pixel_Sizes(face, 0, 48);
    
    int totalCharacters = 128;
    // Calculate rows and columns for grid layout
    int numRows = std::ceil(std::sqrt(totalCharacters));
    int numCols = numRows;  // Assuming square grid for simplicity
    
    TextureSize textureSize = getTextureSize(face, numRows, numCols);
    
    MTL::TextureDescriptor* textureDesc = MTL::TextureDescriptor::alloc()->init();
    textureDesc->setWidth(textureSize.width);
    textureDesc->setHeight(textureSize.height);
    textureDesc->setPixelFormat(MTL::PixelFormatR8Uint);

    MTL::Texture* textureAtlas = metalDevice->newTexture(textureDesc);
    assert(textureAtlas != nullptr);
    
    int row = numRows - 1, col = 0;
    for(unsigned char c = 0; c < totalCharacters; c++) {
        if(FT_Load_Char(face, c, FT_LOAD_RENDER)) {
            std::cout << "ERROR::FREETYPE: Failed to load Glyph" << std::endl;
            continue;
        }
        
        if (face->glyph->bitmap.width == 0) {
            std::cout << "Skipping character " << c << std::endl;
            continue;
        }
        
        int width = face->glyph->bitmap.width;
        int height = face->glyph->bitmap.rows;
        int pitch = face->glyph->bitmap.pitch;

        // Prepare a buffer to hold the formatted pixel data
        unsigned char* formattedBuffer = new unsigned char[abs(pitch) * height];

        // Iterate through each row
        for (int y = 0; y < height; ++y) {
            // Determine the source and destination pointers for this row
            unsigned char* srcRow;
            unsigned char* dstRow;

            if (pitch < 0) {
                // Positive pitch: top-to-bottom
                srcRow = face->glyph->bitmap.buffer + y * pitch;
                dstRow = formattedBuffer + y * abs(pitch);
            } else {
                // Negative pitch: bottom-to-top
                srcRow = face->glyph->bitmap.buffer + (height - 1 - y) * abs(pitch);
                dstRow = formattedBuffer + y * abs(pitch);
            }

            // Copy this row's data
            memcpy(dstRow, srcRow, width);  // assuming 8-bit grayscale here
        }
        
        int offsetX = col * textureSize.maxGlyphWidth;
        int offsetY = row * textureSize.maxGlyphHeight;

        MTL::Region region = MTL::Region(offsetX, offsetY, width, height);
        textureAtlas->replaceRegion(region, 0, (void*)formattedBuffer, pitch);

        // Update UV coordinates
        float uv_x1 = (float) offsetX / (float) textureSize.width;
        float uv_y1 = (float) offsetY / (float) textureSize.height;
        float uv_x2 = (float) (offsetX + width) / (float) textureSize.width;
        float uv_y2 = (float) (offsetY + height) / (float) textureSize.height;

        Character character = {
            textureAtlas,
            (int2){width, height},
            (int2){face->glyph->bitmap_left, face->glyph->bitmap_top},
            (uint)face->glyph->advance.x,
            (float2){uv_x1, uv_y1}, // Top left
            (float2){uv_x2, uv_y2} // Bottom right
        };
        
        Characters.emplace(c, character);

        // Update row and column for the next character
        col++;
        if (col >= numCols) {
            col = 0;
            row--;
        }
    }
    
    for (unsigned char i = 0; i < state->modules.size(); i++) {
        auto mod = state->modules[i];
        for (const char& c : mod.source) {
            if (Characters.find(c) != Characters.end()) {
                // Top left
                uvCoordinates.push_back(Characters.at(c).UV_Start);
                // Top right
                uvCoordinates.push_back((float2){Characters.at(c).UV_End.x, Characters.at(c).UV_Start.y});
                // Bottom right
                
                // Bottom left
                uvCoordinates.push_back((float2){Characters.at(c).UV_Start.x, Characters.at(c).UV_End.y});
                
                uvCoordinates.push_back(Characters.at(c).UV_End);
            }
        }
    }

    textureDesc->release();
    FT_Done_Face(face);
    FT_Done_FreeType(ft);
}

void MTLEngine::generateSphere(float radius, unsigned int rings, unsigned int sectors)
{    
    float const R = 1. / (float)(rings - 1);
    float const S = 1. / (float)(sectors - 1);

    for (unsigned int r = 0; r < rings; ++r)
    {
        for (unsigned int s = 0; s < sectors; ++s)
        {
            float3 v;
            v.y = sin(-(M_PI / 2) + M_PI * r * R);
            v.x = cos(2 * M_PI * s * S) * sin(M_PI * r * R);
            v.z = sin(2 * M_PI * s * S) * sin(M_PI * r * R);

            sphereVertices.push_back(v * radius);
            if (r < rings - 1)
            {
                sphereIndices.push_back(r * sectors + s);
                sphereIndices.push_back(r * sectors + (s + 1));
                sphereIndices.push_back((r + 1) * sectors + (s + 1));
                sphereIndices.push_back((r + 1) * sectors + (s + 1));
                sphereIndices.push_back((r + 1) * sectors + s);
                sphereIndices.push_back(r * sectors + s);
            }
        }
    }
}

void MTLEngine::createDefaultLibrary() {
    metalDefaultLibrary = metalDevice->newDefaultLibrary();
    if(!metalDefaultLibrary){
        std::cerr << "Failed to load default library.";
        std::exit(-1);
    }
}

void MTLEngine::createCommandQueue() {
    metalCommandQueue = metalDevice->newCommandQueue();
}

void MTLEngine::createTextRenderPipeline() {
    MTL::Function* vertexShader = metalDefaultLibrary->newFunction(NS::String::string("textVertexShader", NS::ASCIIStringEncoding));
    assert(vertexShader);
    MTL::Function* fragmentShader = metalDefaultLibrary->newFunction(NS::String::string("textFragmentShader", NS::ASCIIStringEncoding));
    assert(fragmentShader);

    MTL::RenderPipelineDescriptor* renderPipelineDescriptor = MTL::RenderPipelineDescriptor::alloc()->init();
    renderPipelineDescriptor->setLabel(NS::String::string("Text Rendering Pipeline", NS::ASCIIStringEncoding));
    renderPipelineDescriptor->setVertexFunction(vertexShader);
    renderPipelineDescriptor->setFragmentFunction(fragmentShader);
    assert(renderPipelineDescriptor);
    MTL::PixelFormat pixelFormat = (MTL::PixelFormat)metalLayer.pixelFormat;
    renderPipelineDescriptor->colorAttachments()->object(0)->setPixelFormat(pixelFormat);
    renderPipelineDescriptor->setDepthAttachmentPixelFormat(MTL::PixelFormatDepth32Float);
    renderPipelineDescriptor->colorAttachments()->object(0)->setBlendingEnabled(true);
    renderPipelineDescriptor->colorAttachments()->object(0)->setSourceRGBBlendFactor(MTL::BlendFactorSourceAlpha);
    renderPipelineDescriptor->colorAttachments()->object(0)->setDestinationRGBBlendFactor(MTL::BlendFactorOneMinusSourceAlpha);
    renderPipelineDescriptor->colorAttachments()->object(0)->setRgbBlendOperation(MTL::BlendOperationAdd);
    renderPipelineDescriptor->colorAttachments()->object(0)->setSourceAlphaBlendFactor(MTL::BlendFactorOne);
    renderPipelineDescriptor->colorAttachments()->object(0)->setDestinationAlphaBlendFactor(MTL::BlendFactorOneMinusSourceAlpha);

    NS::Error* error;
    metalRenderTextPSO = metalDevice->newRenderPipelineState(renderPipelineDescriptor, &error);
    
    if (metalRenderTextPSO == nil) {
        NSLog(@"Error creating render pipeline state: %@", error);
        std::exit(0);
    }
    
    MTL::SamplerDescriptor* samplerDescriptor = MTL::SamplerDescriptor::alloc()->init();
    // set up your sampler descriptor settings
    samplerState = metalDevice->newSamplerState(samplerDescriptor);


    renderPipelineDescriptor->release();
    vertexShader->release();
    fragmentShader->release();
}


void MTLEngine::createTriangleRenderPipeline() {
    MTL::Function* vertexShader = metalDefaultLibrary->newFunction(NS::String::string("vertexShader", NS::ASCIIStringEncoding));
    assert(vertexShader);
    MTL::Function* fragmentShader = metalDefaultLibrary->newFunction(NS::String::string("fragmentShader", NS::ASCIIStringEncoding));
    assert(fragmentShader);

    MTL::RenderPipelineDescriptor* renderPipelineDescriptor = MTL::RenderPipelineDescriptor::alloc()->init();
    renderPipelineDescriptor->setLabel(NS::String::string("Triangle Rendering Pipeline", NS::ASCIIStringEncoding));
    renderPipelineDescriptor->setVertexFunction(vertexShader);
    renderPipelineDescriptor->setFragmentFunction(fragmentShader);
    assert(renderPipelineDescriptor);
    MTL::PixelFormat pixelFormat = (MTL::PixelFormat)metalLayer.pixelFormat;
    renderPipelineDescriptor->colorAttachments()->object(0)->setPixelFormat(pixelFormat);
    renderPipelineDescriptor->setDepthAttachmentPixelFormat(MTL::PixelFormatDepth32Float);

    NS::Error* error;
    metalRenderTrianglePSO = metalDevice->newRenderPipelineState(renderPipelineDescriptor, &error);
    
    if (metalRenderTrianglePSO == nil) {
        NSLog(@"Error creating render pipeline state: %@", error);
        std::exit(0);
    }
    
    MTL::DepthStencilDescriptor* depthStencilDescriptor = MTL::DepthStencilDescriptor::alloc()->init();
    depthStencilDescriptor->setDepthCompareFunction(MTL::CompareFunctionLessEqual);
    depthStencilDescriptor->setDepthWriteEnabled(true);
    depthStencilState = metalDevice->newDepthStencilState(depthStencilDescriptor);

    renderPipelineDescriptor->release();
    vertexShader->release();
    fragmentShader->release();
}

void MTLEngine::init(State* initState) {
    state = initState;
    initDevice();
    initWindow();
    initText();
    camera = Camera();
    
    generateSphere(0.1, 32, 32);

    sphereVertexBuffer = metalDevice->newBuffer(sphereVertices.data(), sizeof(float3) * sphereVertices.size(), MTL::ResourceStorageModeShared);
    sphereIndexBuffer = metalDevice->newBuffer(sphereIndices.data(), sizeof(uint32) * sphereIndices.size(), MTL::ResourceStorageModeShared);

    createDefaultLibrary();
    createCommandQueue();
    createTriangleRenderPipeline();
    createTextRenderPipeline();
    
    MTL::TextureDescriptor* depthTextureDescriptor = MTL::TextureDescriptor::alloc()->init();
    depthTextureDescriptor->setPixelFormat(MTL::PixelFormatDepth32Float);
    depthTextureDescriptor->setWidth(WIDTH);
    depthTextureDescriptor->setHeight(HEIGHT);
    depthTextureDescriptor->setUsage(MTL::TextureUsageRenderTarget);

    depthTexture = metalDevice->newTexture(depthTextureDescriptor);
    
    depthTextureDescriptor->release();
    
    renderPassDescriptor = MTL::RenderPassDescriptor::alloc()->init();
    
    MTL::RenderPassColorAttachmentDescriptor* colorAttachment = renderPassDescriptor->colorAttachments()->object(0);
    MTL::RenderPassDepthAttachmentDescriptor* depthAttachment = renderPassDescriptor->depthAttachment();
    
    colorAttachment->setTexture(metalDrawable->texture());
    colorAttachment->setLoadAction(MTL::LoadActionClear);
    colorAttachment->setClearColor(MTL::ClearColor(41.0f/255.0f, 42.0f/255.0f, 48.0f/255.0f, 1.0));
    colorAttachment->setStoreAction(MTL::StoreActionStore);
    
    depthAttachment->setTexture(depthTexture);
    depthAttachment->setLoadAction(MTL::LoadActionClear);
    depthAttachment->setClearDepth(1.0f); // Clear to the farthest depth value
    depthAttachment->setStoreAction(MTL::StoreActionStore);
}

void MTLEngine::sendRenderCommand(State* state) {
    metalCommandBuffer = metalCommandQueue->commandBuffer();
    
    renderPassDescriptor->depthAttachment()->setTexture(depthTexture);
    renderPassDescriptor->colorAttachments()->object(0)->setTexture(metalDrawable->texture());
    
    MTL::RenderCommandEncoder* renderCommandEncoder = metalCommandBuffer->renderCommandEncoder(renderPassDescriptor);
    encodeRenderCommand(renderCommandEncoder, state);
    renderCommandEncoder->endEncoding();

    metalCommandBuffer->presentDrawable(metalDrawable);
    metalCommandBuffer->commit();
    metalCommandBuffer->waitUntilCompleted();
}

void MTLEngine::renderEntities(MTL::RenderCommandEncoder* renderCommandEncoder, std::vector<float4x4> transforms, std::vector<NodeState> selections, MTL::Buffer* vertexBuffer, MTL::Buffer* indexBuffer, int numberOfIndices) {
    MTL::Buffer* offsetBuffer = metalDevice->newBuffer(transforms.data(), sizeof(float4x4) * transforms.size(), MTL::ResourceStorageModeShared);
    MTL::Buffer* selectionBuffer = metalDevice->newBuffer(selections.data(), sizeof(short) * selections.size(), MTL::ResourceStorageModeShared);

    // Set vertex buffers
    renderCommandEncoder->setVertexBuffer(vertexBuffer, 0, 0);

    renderCommandEncoder->setVertexBuffer(offsetBuffer, 0, 1);
    renderCommandEncoder->setVertexBytes(&viewMatrix, sizeof(viewMatrix), 2);
    renderCommandEncoder->setVertexBytes(&projectionMatrix, sizeof(projectionMatrix), 3);
    renderCommandEncoder->setVertexBuffer(selectionBuffer, 0, 4);
    
    
    MTL::PrimitiveType typeTriangle = MTL::PrimitiveTypeTriangle;
    // Draw spheres
    renderCommandEncoder->drawIndexedPrimitives(typeTriangle, numberOfIndices, MTL::IndexTypeUInt32, indexBuffer, 0, transforms.size());
    
    offsetBuffer->release();
    selectionBuffer->release();
}

void MTLEngine::encodeRenderCommand(MTL::RenderCommandEncoder* renderCommandEncoder, State* state) {
    renderCommandEncoder->setRenderPipelineState(metalRenderTrianglePSO);
    renderCommandEncoder->setDepthStencilState(depthStencilState);
    
    

    // Create a new buffer for offsets
    renderEntities(renderCommandEncoder, state->nodes, state->nodeStates, sphereVertexBuffer, sphereIndexBuffer, sphereIndices.size());
    MTL::PrimitiveType typeTriangle = MTL::PrimitiveTypeTriangle;
//    MTL::Buffer* offsetBuffer = metalDevice->newBuffer(state->nodes.data(), sizeof(float3) * state->nodes.size(), MTL::ResourceStorageModeShared);
//    MTL::Buffer* selectionBuffer = metalDevice->newBuffer(state->nodeStates.data(), sizeof(short) * state->nodeStates.size(), MTL::ResourceStorageModeShared);
//
//    // Set vertex buffers
//    renderCommandEncoder->setVertexBuffer(sphereVertexBuffer, 0, 0);
//
//    renderCommandEncoder->setVertexBuffer(offsetBuffer, 0, 1);
//    renderCommandEncoder->setVertexBytes(&viewMatrix, sizeof(viewMatrix), 2);
//    renderCommandEncoder->setVertexBytes(&projectionMatrix, sizeof(projectionMatrix), 3);
//    renderCommandEncoder->setVertexBuffer(selectionBuffer, 0, 4);
//
//
//    MTL::PrimitiveType typeTriangle = MTL::PrimitiveTypeTriangle;
//    // Draw spheres
//    renderCommandEncoder->drawIndexedPrimitives(typeTriangle, sphereIndices.size(), MTL::IndexTypeUInt32, sphereIndexBuffer, 0, state->nodes.size());
    
    // Create a buffer for edge vertices
    std::vector<float3> edgeVertices;

    for (auto& edge : state->edges) {
        edgeVertices.push_back(edge.node1);
        edgeVertices.push_back(edge.node2);
    }
    float4x4 offset = float4x4(1.0f);
    offset.columns[3].xyz = (float3){0.0f, 0.0f, 0.0f};
    short selection = 0;
    
    MTL::Buffer* edgeVertexBuffer = metalDevice->newBuffer(edgeVertices.data(), sizeof(float3) * edgeVertices.size(), MTL::ResourceStorageModeShared);
    MTL::Buffer* offsetBuffer2 = metalDevice->newBuffer(&offset, sizeof(float4x4), MTL::ResourceStorageModeShared);
    MTL::Buffer* selectionBuffer2 = metalDevice->newBuffer(&selection, sizeof(short), MTL::ResourceStorageModeShared);
    // Draw edges
    renderCommandEncoder->setVertexBuffer(edgeVertexBuffer, 0, 0);
    renderCommandEncoder->setVertexBuffer(offsetBuffer2, 0, 1);
    renderCommandEncoder->setVertexBytes(&viewMatrix, sizeof(viewMatrix), 2);
    renderCommandEncoder->setVertexBytes(&projectionMatrix, sizeof(projectionMatrix), 3);
    renderCommandEncoder->setVertexBuffer(selectionBuffer2, 0, 4);
    renderCommandEncoder->drawPrimitives(MTL::PrimitiveTypeLine, static_cast<NSUInteger>(0), static_cast<NSUInteger>(edgeVertices.size()));
    
    // Draw text
    renderCommandEncoder->setRenderPipelineState(metalRenderTextPSO);
    
    const float textVertexData[] = {
        -0.5f, -0.5f, 0.0f, 1.0f,
         0.5f, -0.5f, 0.0f, 1.0f,
        -0.5f,  0.5f, 0.0f, 1.0f,
         0.5f,  0.5f, 0.0f, 1.0f,
    };
    
    const uint16_t indices[] = {
        0, 1, 2,
        1, 3, 2
    };
    
    std::vector<float4x4> characterModels;
    for (unsigned short i = 0; i < state->modules.size(); i++) {
        auto mod = state->modules[i];
        float advance = 0.0f;
        for (unsigned short j = 0; j < mod.source.length(); j++) {
            char c = mod.source[j];
            if (Characters.find(c) != Characters.end()) {
                int width = Characters.at(c).Size.x;
                int height = Characters.at(c).Size.y;
                float4x4 modelMatrix = float4x4(1.0);
                
                modelMatrix.columns[0][0] = 0.3f * (float)width / (float)height;
                modelMatrix.columns[1][1] = 0.3f;
                
                modelMatrix.columns[3][0] = state->nodes[i].columns[3].x + advance;
                modelMatrix.columns[3][1] = state->nodes[i].columns[3].y;
                modelMatrix.columns[3][2] = state->nodes[i].columns[3].z - 1.0f;
                characterModels.push_back(modelMatrix);
                advance += 0.3f;
            }
        }
    }
    
    MTL::Buffer* textPositionsBuffer = metalDevice->newBuffer(textVertexData, sizeof(float4) * 4, MTL::ResourceStorageModeShared);
    MTL::Buffer* indexBuffer = metalDevice->newBuffer(indices, sizeof(uint16_t) * 6, MTL::ResourceStorageModeShared);
    MTL::Buffer* characterModelsBuffer = metalDevice->newBuffer(characterModels.data(), sizeof(float4x4) * characterModels.size(), MTL::ResourceStorageModeShared);
    MTL::Buffer* uvBuffer = metalDevice->newBuffer(uvCoordinates.data(), sizeof(float2) * uvCoordinates.size(), MTL::ResourceStorageModeShared);
    
    renderCommandEncoder->setVertexBuffer(textPositionsBuffer, 0, 0);
    renderCommandEncoder->setVertexBuffer(characterModelsBuffer, 0, 1);
    renderCommandEncoder->setVertexBytes(&viewMatrix, sizeof(viewMatrix), 2);
    renderCommandEncoder->setVertexBytes(&projectionMatrix, sizeof(projectionMatrix), 3);
    renderCommandEncoder->setVertexBuffer(uvBuffer, 0, 4);
    renderCommandEncoder->setFragmentTexture(Characters.at(0).textureAtlas, 0);
    renderCommandEncoder->setFragmentSamplerState(samplerState, 0);
    renderCommandEncoder->drawIndexedPrimitives(typeTriangle, 6, MTL::IndexTypeUInt16, indexBuffer, 0, 10);

    
    // Release the offset and edge vertex buffers
    offsetBuffer2->release();
    edgeVertexBuffer->release();
}



void MTLEngine::run() {
    double lastFrameTime = glfwGetTime();

    while (!glfwWindowShouldClose(glfwWindow)) {
        @autoreleasepool {
            double currentFrameTime = glfwGetTime();
            float deltaTime = currentFrameTime - lastFrameTime;
            lastFrameTime = currentFrameTime;
            
            metalDrawable = (__bridge CA::MetalDrawable*)[metalLayer nextDrawable];
            // Engine
            update(state);
            
            // Events
            if (glfwGetKey(glfwWindow, GLFW_KEY_W) == GLFW_PRESS)
                camera.ProcessKeyboard(FORWARD, deltaTime);
            if (glfwGetKey(glfwWindow, GLFW_KEY_S) == GLFW_PRESS)
                camera.ProcessKeyboard(BACKWARD, deltaTime);
            if (glfwGetKey(glfwWindow, GLFW_KEY_A) == GLFW_PRESS)
                camera.ProcessKeyboard(LEFT, deltaTime);
            if (glfwGetKey(glfwWindow, GLFW_KEY_D) == GLFW_PRESS)
                camera.ProcessKeyboard(RIGHT, deltaTime);
            
            viewMatrix = camera.GetViewMatrix();
            // Aspect ratio should match the ratio between the window width and height,
            // otherwise the image will look stretched.
            float aspectRatio = ((float)WIDTH / (float)HEIGHT);
            float fov = camera.Zoom * (M_PI / 180.0f);
            float nearZ = 0.1f;
            float farZ = 100.0f;
            projectionMatrix = matrix_perspective_left_hand(fov, aspectRatio, nearZ, farZ);
            
            
            // Draw
            sendRenderCommand(state);
        }
        glfwPollEvents();
    }
}



void MTLEngine::cleanup() {
    glfwTerminate();
    metalDevice->release();
}

void MTLEngine::initDevice() {
    metalDevice = MTL::CreateSystemDefaultDevice();
}

bool rayIntersectsSphere(float3 rayOrigin, float3 rayDirection, float3 spherePosition, float radius) {
    float3 oc = rayOrigin - spherePosition;
    float a = dot(rayDirection, rayDirection);
    float b = 2.0f * dot(oc, rayDirection);
    float c = dot(oc, oc) - radius * radius;
    float discriminant = b*b - 4*a*c;
    return discriminant > 0;
}

void mouseButton(GLFWwindow *window, int button, int action, int mods)
{
    double xPos, yPos;
    glfwGetCursorPos(window, &xPos, &yPos);
    // Only start motion if the left button is pressed
    if (button == GLFW_MOUSE_BUTTON_LEFT)
    {
        // When the button is released
        if (action == GLFW_RELEASE)
        {
            xOrigin = -1;
            yOrigin = -1;
        }
        else
        {
            // Normalize mouse coordinates
            float x = (2.0f * xPos) / WIDTH - 1.0f;
            float y = 1.0f - (2.0f * yPos) / HEIGHT;
            MTLEngine *engine = engines[window];
            float3 rayDir = engine->camera.GetRayDirection((float2){x, y}, engine->projectionMatrix, engine->viewMatrix);
            float minZ = INFINITY;
            int selectedIdx = -1;
            for (int i = 0; i < state->nodes.size(); i++)
            {
                auto spherePosition = state->nodes[i].columns[3].xyz;
                if (spherePosition.z < minZ && rayIntersectsSphere(engine->camera.Position, rayDir, spherePosition, 0.1f))
                {
                    selectedIdx = i;
                    minZ = spherePosition.z;
                }
                state->nodeStates[i].selection = IDLE;
            }
            if (selectedIdx != -1) {
                state->nodeStates[selectedIdx].selection = SELECTED;
                for (int j=0; j < state->modules[selectedIdx].dependencies.size(); j++) {
                    state->nodeStates[state->modules[selectedIdx].dependencies[j]].selection = SELECTED_CONNECTED;
                }
            }
            xOrigin = xPos;
            yOrigin = yPos;
        }
    }
};

void mouseMove(GLFWwindow *window, double xPos, double yPos) {
   MTLEngine *engine = engines[window];
   if (xOrigin >= 0)
   {
       engine->camera.ProcessMouseMovement(xPos - xOrigin, yPos - yOrigin);
       xOrigin = xPos;
       yOrigin = yPos;
   }
};

void MTLEngine::initWindow() {
    glfwInit();
    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
    glfwWindow = glfwCreateWindow(WIDTH, HEIGHT, "Metal Engine", NULL, NULL);
    if (!glfwWindow) {
        glfwTerminate();
        exit(EXIT_FAILURE);
    }
    
    engines[glfwWindow] = this;
    
    glfwSetMouseButtonCallback(glfwWindow, mouseButton);
    glfwSetCursorPosCallback(glfwWindow, mouseMove);

    metalWindow = glfwGetCocoaWindow(glfwWindow);
    metalLayer = [CAMetalLayer layer];
    metalLayer.device = (__bridge id<MTLDevice>)metalDevice;
    metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    metalLayer.drawableSize = CGSizeMake(WIDTH, HEIGHT);
    metalWindow.contentView.layer = metalLayer;
    metalWindow.contentView.wantsLayer = YES;
    
    metalDrawable = (__bridge CA::MetalDrawable*)[metalLayer nextDrawable];
}
