RSRC                    RDShaderFile            ��������                                                  resource_local_to_scene    resource_name    bytecode_vertex    bytecode_fragment    bytecode_tesselation_control     bytecode_tesselation_evaluation    bytecode_compute    compile_error_vertex    compile_error_fragment "   compile_error_tesselation_control %   compile_error_tesselation_evaluation    compile_error_compute    script 
   _versions    base_error           local://RDShaderSPIRV_37aya ;         local://RDShaderFile_eq6yc �         RDShaderSPIRV          >  Failed parse:
ERROR: 0:129: 'sample_blurred_wide' : no matching overloaded function found 
ERROR: 0:129: '' : missing #endif 
ERROR: 0:129: '=' :  cannot convert from ' const float' to ' temp highp 2-component vector of float'
ERROR: 0:129: '' : compilation terminated 
ERROR: 4 compilation errors.  No code generated.




Stage 'compute' source code: 

1		
2		#version 450
3		
4		#
5		
6		layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
7		
8		layout(set = 0, binding = 0) uniform sampler2D source_ssao;
9		
10		layout(rg8, set = 1, binding = 0) uniform restrict writeonly image2D dest_image;
11		
12		layout(push_constant, std430) uniform Params {
13			float edge_sharpness;
14			float pad;
15			vec2 half_screen_pixel_size;
16		}
17		params;
18		
19		vec4 unpack_edges(float p_packed_val) {
20			uint packed_val = uint(p_packed_val * 255.5);
21			vec4 edgesLRTB;
22			edgesLRTB.x = float((packed_val >> 6) & 0x03) / 3.0;
23			edgesLRTB.y = float((packed_val >> 4) & 0x03) / 3.0;
24			edgesLRTB.z = float((packed_val >> 2) & 0x03) / 3.0;
25			edgesLRTB.w = float((packed_val >> 0) & 0x03) / 3.0;
26		
27			return clamp(edgesLRTB + params.edge_sharpness, 0.0, 1.0);
28		}
29		
30		void add_sample(float p_ssao_value, float p_edge_value, inout float r_sum, inout float r_sum_weight) {
31			float weight = p_edge_value;
32		
33			r_sum += (weight * p_ssao_value);
34			r_sum_weight += weight;
35		}
36		
37		#ifdef MODE_WIDE
38		vec2 sample_blurred_wide(vec2 p_coord) {
39			vec2 vC = textureLodOffset(source_ssao, vec2(p_coord), 0.0, ivec2(0, 0)).xy;
40			vec2 vL = textureLodOffset(source_ssao, vec2(p_coord), 0.0, ivec2(-2, 0)).xy;
41			vec2 vT = textureLodOffset(source_ssao, vec2(p_coord), 0.0, ivec2(0, -2)).xy;
42			vec2 vR = textureLodOffset(source_ssao, vec2(p_coord), 0.0, ivec2(2, 0)).xy;
43			vec2 vB = textureLodOffset(source_ssao, vec2(p_coord), 0.0, ivec2(0, 2)).xy;
44		
45			float packed_edges = vC.y;
46			vec4 edgesLRTB = unpack_edges(packed_edges);
47			edgesLRTB.x *= unpack_edges(vL.y).y;
48			edgesLRTB.z *= unpack_edges(vT.y).w;
49			edgesLRTB.y *= unpack_edges(vR.y).x;
50			edgesLRTB.w *= unpack_edges(vB.y).z;
51		
52			float ssao_value = vC.x;
53			float ssao_valueL = vL.x;
54			float ssao_valueT = vT.x;
55			float ssao_valueR = vR.x;
56			float ssao_valueB = vB.x;
57		
58			float sum_weight = 0.8f;
59			float sum = ssao_value * sum_weight;
60		
61			add_sample(ssao_valueL, edgesLRTB.x, sum, sum_weight);
62			add_sample(ssao_valueR, edgesLRTB.y, sum, sum_weight);
63			add_sample(ssao_valueT, edgesLRTB.z, sum, sum_weight);
64			add_sample(ssao_valueB, edgesLRTB.w, sum, sum_weight);
65		
66			float ssao_avg = sum / sum_weight;
67		
68			ssao_value = ssao_avg;
69		
70			return vec2(ssao_value, packed_edges);
71		}
72		#endif
73		
74		#ifdef MODE_SMART
75		vec2 sample_blurred(vec3 p_pos, vec2 p_coord) {
76			float packed_edges = texelFetch(source_ssao, ivec2(p_pos.xy), 0).y;
77			vec4 edgesLRTB = unpack_edges(packed_edges);
78		
79			vec4 valuesUL = textureGather(source_ssao, vec2(p_coord - params.half_screen_pixel_size * 0.5));
80			vec4 valuesBR = textureGather(source_ssao, vec2(p_coord + params.half_screen_pixel_size * 0.5));
81		
82			float ssao_value = valuesUL.y;
83			float ssao_valueL = valuesUL.x;
84			float ssao_valueT = valuesUL.z;
85			float ssao_valueR = valuesBR.z;
86			float ssao_valueB = valuesBR.x;
87		
88			float sum_weight = 0.5;
89			float sum = ssao_value * sum_weight;
90		
91			add_sample(ssao_valueL, edgesLRTB.x, sum, sum_weight);
92			add_sample(ssao_valueR, edgesLRTB.y, sum, sum_weight);
93		
94			add_sample(ssao_valueT, edgesLRTB.z, sum, sum_weight);
95			add_sample(ssao_valueB, edgesLRTB.w, sum, sum_weight);
96		
97			float ssao_avg = sum / sum_weight;
98		
99			ssao_value = ssao_avg;
100		
101			return vec2(ssao_value, packed_edges);
102		}
103		#endif
104		
105		void main() {
106			// Pixel being shaded
107			ivec2 ssC = ivec2(gl_GlobalInvocationID.xy);
108		
109		#ifdef MODE_NON_SMART
110		
111			vec2 half_pixel = params.half_screen_pixel_size * 0.5;
112		
113			vec2 uv = (vec2(gl_GlobalInvocationID.xy) + vec2(0.5, 0.5)) * params.half_screen_pixel_size;
114		
115			vec2 center = textureLod(source_ssao, vec2(uv), 0.0).xy;
116		
117			vec4 vals;
118			vals.x = textureLod(source_ssao, vec2(uv + vec2(-half_pixel.x * 3, -half_pixel.y)), 0.0).x;
119			vals.y = textureLod(source_ssao, vec2(uv + vec2(+half_pixel.x, -half_pixel.y * 3)), 0.0).x;
120			vals.z = textureLod(source_ssao, vec2(uv + vec2(-half_pixel.x, +half_pixel.y * 3)), 0.0).x;
121			vals.w = textureLod(source_ssao, vec2(uv + vec2(+half_pixel.x * 3, +half_pixel.y)), 0.0).x;
122		
123			vec2 sampled = vec2(dot(vals, vec4(0.2)) + center.x * 0.2, center.y);
124		
125		#else
126		#ifdef MODE_SMART
127			vec2 sampled = sample_blurred(vec3(gl_GlobalInvocationID), (vec2(gl_GlobalInvocationID.xy) + vec2(0.5, 0.5)) * params.half_screen_pixel_size);
128		#else // MODE_WIDE
129			vec2 sampled = sample_blurred_wide((vec2(gl_GlobalInvocationID.xy) + vec2(0.5, 0.5)) * params.half_screen_pixel_size);
130		#endif
131		
132		#endif
133			imageStore(dest_image, ivec2(ssC), vec4(sampled, 0.0, 0.0));
134		}
135		
136		
          RDShaderFile                                    RSRC