RSRC                    RDShaderFile            ��������                                                  resource_local_to_scene    resource_name    bytecode_vertex    bytecode_fragment    bytecode_tesselation_control     bytecode_tesselation_evaluation    bytecode_compute    compile_error_vertex    compile_error_fragment "   compile_error_tesselation_control %   compile_error_tesselation_evaluation    compile_error_compute    script 
   _versions    base_error           local://RDShaderSPIRV_sgulb ;         local://RDShaderFile_aeraf (         RDShaderSPIRV          L  #                     GLSL.std.450                      main    	        �       main      	   uv_interp   G  	               !                                        ;     	      +     
       +          �?,        
      6               �     >  	      �  8        k  Failed parse:
ERROR: 0:9: 'assign' :  l-value required "uv_interp" (can't modify shader input)
ERROR: 0:9: '' : compilation terminated 
ERROR: 2 compilation errors.  No code generated.




Stage 'fragment' source code: 

1		
2		#version 450
3		
4		#
5		
6		layout(location = 0) in vec2 uv_interp;
7		
8		void main() {
9			uv_interp = vec2(1, 0);
10		}
11		
12		
          RDShaderFile                                    RSRC