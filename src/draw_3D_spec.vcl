; 2024 - Daniel Santos
; AthenaEnv Renderer
;
; 
;
; 
;---------------------------------------------------------------
; draw_3D_spec.vcl                                             |
;---------------------------------------------------------------
; A VU1 microprogram to draw 3D object using XYZ2, RGBAQ and ST|
; This program uses double buffering (xtop)                    |
;                                                              |
; Many thanks to:                                              |
; - Dr Henry Fortuna                                           |
; - Jesper Svennevid, Daniel Collin                            |
; - Guilherme Lampert                                          |
;---------------------------------------------------------------

.syntax new
.name VU1Draw3DSpec
.vu
.init_vf_all
.init_vi_all

.include "vcl_sml.i"

--enter
--endenter

    ;//////////// --- Load data 1 --- /////////////
    ; Updated once per mesh
    MatrixLoad	ObjectToScreen, 0, vi00 ; load view-projection matrix
    MatrixLoad	LocalLight,     4, vi00     ; load local light matrix
    ;/////////////////////////////////////////////

	fcset   0x000000	; VCL won't let us use CLIP without first zeroing
				; the clip flags

    ;//////////// --- Load data 2 --- /////////////
    ; Updated dynamically
    xtop    iBase

    lq.xyz  scale,          0(iBase) ; load program params
                                     ; float : X, Y, Z - scale vector that we will use to scale the verts after projecting them.
                                     ; float : W - vert count.
    lq      gifSetTag,      1(iBase) ; GIF tag - set
    lq      texGifTag1,     2(iBase) ; GIF tag - texture LOD
    lq      texGifTag2,     3(iBase) ; GIF tag - texture buffer & CLUT
    lq      primTag,        4(iBase) ; GIF tag - tell GS how many data we will send
    lq      rgba,           5(iBase) ; RGBA
                                     ; u32 : R, G, B, A (0-128)
    iaddiu  vertexData,     iBase,      6           ; pointer to vertex data
    ilw.w   vertCount,      0(iBase)                ; load vert count from scale vector
    iadd    stqData,        vertexData, vertCount   ; pointer to stq
    iadd    colorData,      stqData,    vertCount   ; pointer to colors
    iadd    normalData,     colorData,  vertCount   ; pointer to colors
    iadd    CamData,        normalData,  vertCount
    lq      CamPos,         0(CamData) ; load program params
    iaddiu  lightsData,     CamData,      1       
    MatrixLoad	LightDirection,   0,   lightsData   ; load light directions
    MatrixLoad	LightAmbient,     4,   lightsData   ; load light ambients
    MatrixLoad	LightDiffuse,     8,   lightsData   ; load light diffuses
    MatrixLoad	LightSpecular,    12,  lightsData   ; load light diffuses
    iaddiu    kickAddress,    lightsData,  16       ; pointer for XGKICK
    iaddiu    destAddress,    lightsData,  16       ; helper pointer for data inserting
    ;////////////////////////////////////////////

    ;/////////// --- Store tags --- /////////////
    sqi gifSetTag,  (destAddress++) ;
    sqi texGifTag1, (destAddress++) ; texture LOD tag
    sqi gifSetTag,  (destAddress++) ;
    sqi texGifTag2, (destAddress++) ; texture buffer & CLUT tag
    sqi primTag,    (destAddress++) ; prim + tell gs how many data will be
    ;////////////////////////////////////////////

    ;/////////////// --- Loop --- ///////////////
    iadd vertexCounter, iBase, vertCount ; loop vertCount times
    vertexLoop:

        ;////////// --- Load loop data --- //////////
        lq inVert, 0(vertexData)    ; load xyz
                                    ; float : X, Y, Z
                                    ; any32 : _ = 0
        lq stq,    0(stqData)       ; load stq
                                    ; float : S, T
                                    ; any32 : Q = 1     ; 1, because we will mul this by 1/vert[w] and this
                                                        ; will be our q for texture perspective correction
                                    ; any32 : _ = 0 
        lq.xyzw color,  0(colorData) ; load color
        lq.xyzw inNorm,  0(normalData) ; load normal                    
        ;////////////////////////////////////////////    


        ;////////////// --- Vertex --- //////////////
        MatrixMultiplyVertex	vertex, ObjectToScreen, inVert ; transform each vertex by the matrix
       
        clipw.xyz	vertex, vertex			; Dr. Fortuna: This instruction checks if the vertex is outside
							; the viewing frustum. If it is, then the appropriate
							; clipping flags are set
        fcand		VI01,   0x3FFFF                 ; Bitwise AND the clipping flags with 0x3FFFF, this makes
							; sure that we get the clipping judgement for the last three
							; verts (i.e. that make up the triangle we are about to draw)
        iaddiu		iADC,   VI01,       0x7FFF      ; Add 0x7FFF. If any of the clipping flags were set this will
							; cause the triangle not to be drawn (any values above 0x8000
							; that are stored in the w component of XYZ2 will set the ADC
							; bit, which tells the GS not to perform a drawing kick on this
							; triangle.

        isw.w		iADC,   2(destAddress)
        
        div         q,      vf00[w],    vertex[w]   ; perspective divide (1/vert[w]):
        mul.xyz     vertex, vertex,     q
        mula.xyz    acc,    scale,      vf00[w]     ; scale to GS screen space
        madd.xyz    vertex, vertex,     scale       ; multiply and add the scales -> vert = vert * scale + scale
        ftoi4.xyz   vertex, vertex                  ; convert vertex to 12:4 fixed point format
        ;////////////////////////////////////////////


        ;//////////////// --- ST --- ////////////////
        mulq modStq, stq, q
        ;////////////////////////////////////////////

        ;//////////////// - NORMALS - /////////////////
        MatrixMultiplyVertex	normal, LocalLight, inNorm ; transform each normal by the matrix
        MatrixMultiplyVertex	lightvert, LocalLight, inVert ; transform each normal by the matrix
        div         q,      vf00[w],    normal[w]   ; perspective divide (1/vert[w]):
        mul.xyz     normal, normal,     q
        
        add light, vf00, vf00
        add light, light, LightAmbient[0]
        add light, light, LightAmbient[1]
        add light, light, LightAmbient[2]
        add light, light, LightAmbient[3]

        add intensity, vf00, vf00

        loi  -1.0              
        addi minusOne, vf00, i

        VectorDotProduct intensity, normal, LightDirection[0]
        
        mul intensity, intensity, minusOne
        maxx.xyzw  intensity, intensity, vf00

        mul diffuse, LightDiffuse[0], intensity[x]
        add light, light, diffuse

        ; Blinn-Phong Lighting Calculation
        ;VectorNormalize CamPos, CamPos

        ;sub lightDir, lightvert, CamPos ; Compute light direction vector
        ;VectorNormalize lightDir, lightDir

        ; Compute halfway vector
        add halfDir, LightDirection[0], CamPos
        VectorNormalize halfDir, halfDir

        add specAngle, vf00, vf00
        VectorDotProduct specAngle, normal, halfDir
        maxx		specAngle, specAngle, vf00			; Clamp to > 0
        mul  		specAngle, specAngle, specAngle	; Square it
	    mul  		specAngle, specAngle, specAngle	; 4th power
	    mul  		specAngle, specAngle, specAngle	; 8th power
	    mul  		specAngle, specAngle, specAngle	; 16th power
	    ;mul 		specAngle, specAngle, specAngle	; 32nd power
        ;mul 		specAngle, specAngle, specAngle	; 64nd power
        mul         specAngle, LightSpecular[0], specAngle[x]
        add         light, light, specAngle 

        VectorDotProduct intensity, normal, LightDirection[1]
        
        mul intensity, intensity, minusOne
        maxx.xyzw  intensity, intensity, vf00

        mul diffuse, LightDiffuse[1], intensity[x]
        add light, light, diffuse

        VectorDotProduct intensity, normal, LightDirection[2]
        
        mul intensity, intensity, minusOne
        maxx.xyzw  intensity, intensity, vf00

        mul diffuse, LightDiffuse[2], intensity[x]
        add light, light, diffuse

        VectorDotProduct intensity, normal, LightDirection[3]
        
        mul intensity, intensity, minusOne
        maxx.xyzw  intensity, intensity, vf00

        mul diffuse, LightDiffuse[3], intensity[x]
        add light, light, diffuse

        mul.xyz    color, color,  light            ; color = color * light
        VectorClamp color, color 0.0 1.0
        mul color, color, rgba                     ; normalize RGBA
        ColorFPtoGsRGBAQ intColor, color           ; convert to int
        ;///////////////////////////////////////////


        ;//////////// --- Store data --- ////////////
        sq modStq,      0(destAddress)      ; STQ
        sq intColor,    1(destAddress)      ; RGBA ; q is grabbed from stq
        sq.xyz vertex,  2(destAddress)      ; XYZ2
        ;////////////////////////////////////////////

        iaddiu          vertexData,     vertexData,     1                         
        iaddiu          stqData,        stqData,        1  
        iaddiu          colorData,      colorData,      1  
        iaddiu          normalData,     normalData,      1
        iaddiu          destAddress,    destAddress,    3

        iaddi   vertexCounter,  vertexCounter,  -1	; decrement the loop counter 
        ibne    vertexCounter,  iBase,   vertexLoop	; and repeat if needed

    ;//////////////////////////////////////////// 

    --barrier

    xgkick kickAddress ; dispatch to the GS rasterizer.

--exit
--endexit
