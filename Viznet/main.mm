#include "mtl_engine.hpp"
#include "parser.h"
#include "graph_engine.hpp"
#include <iostream>
#include "ft2build.h"
#include FT_FREETYPE_H


int main() {

//    FT_Library ft;
//    if (FT_Init_FreeType(&ft))
//    {
//        std::cout << "ERROR::FREETYPE: Could not init FreeType Library" << std::endl;
//        return -1;
//    }
//
//    FT_Face face;
//    if (FT_New_Face(ft, "fonts/arial.ttf", 0, &face))
//    {
//        std::cout << "ERROR::FREETYPE: Failed to load font" << std::endl;
//        return -1;
//    }
//
//    FT_Set_Pixel_Sizes(face, 0, 48);
//
//
//    if (FT_Load_Char(face, 'X', FT_LOAD_RENDER))
//    {
//        std::cout << "ERROR::FREETYTPE: Failed to load Glyph" << std::endl;
//        return -1;
//    }
//
//    struct Character {
//        unsigned int TextureID;  // ID handle of the glyph texture
//        glm::ivec2   Size;       // Size of glyph
//        glm::ivec2   Bearing;    // Offset from baseline to left/top of glyph
//        unsigned int Advance;    // Offset to advance to next glyph
//    };
//
//    std::map<char, Character> Characters;
    
    

    
    MTLEngine engine;
    State state;
    state.modules = load_json_file("data/graph.json");
    initNodes(&state);
    

    engine.init(&state);
    engine.run();
    engine.cleanup();

    return 0;
}
