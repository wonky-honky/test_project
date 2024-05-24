RSRC                    RDShaderFile            ��������                                                  resource_local_to_scene    resource_name    bytecode_vertex    bytecode_fragment    bytecode_tesselation_control     bytecode_tesselation_evaluation    bytecode_compute    compile_error_vertex    compile_error_fragment "   compile_error_tesselation_control %   compile_error_tesselation_evaluation    compile_error_compute    script 
   _versions    base_error           local://RDShaderSPIRV_sgo1b ;         local://RDShaderFile_ag22q x         RDShaderSPIRV            Failed parse:
ERROR: 0:119: 'sample_blurred_wide' : no matching overloaded function found 
ERROR: 0:119: '' : missing #endif 
ERROR: 0:119: '=' :  cannot convert from ' const float' to ' temp highp 4-component vector of float'
ERROR: 0:119: '' : compilation terminated 
ERROR: 4 compilation errors.  No code generated.




Stage 'compute' source code: 

1		
2		#version 450
3		
4		#
5		
6		layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
7		
8		layout(set = 0, binding = 0) uniform sampler2D source_ssil;
9		
10		layout(rgba16, set = 1, binding = 0) uniform restrict writeonly image2D dest_image;
11		
12		layout(r8, set = 2, binding = 0) uniform restrict readonly image2D source_edges;
13		
14		layout(push_constant, std430) uniform Params {
15			float edge_sharpness;
16			float pad;
17			vec2 half_screen_pixel_size;
18		}
19		params;
20		
21		vec4 unpack_edges(float p_packed_val) {
22			uint packed_val = uint(p_packed_val * 255.5);
23			vec4 edgesLRTB;
24			edgesLRTB.x = float((packed_val >> 6) & 0x03) / 3.0;
25			edgesLRTB.y = float((packed_val >> 4) & 0x03) / 3.0;
26			edgesLRTB.z = float((packed_val >> 2) & 0x03) / 3.0;
27			edgesLRTB.w = float((packed_val >> 0) & 0x03) / 3.0;
28		
29			return clamp(edgesLRTB + params.edge_sharpness, 0.0, 1.0);
30		}
31		
32		void add_sample(vec4 p_ssil_value, float p_edge_value, inout vec4 r_sum, inout float r_sum_weight) {
33			float weight = p_edge_value;
34		
35			r_sum += (weight * p_ssil_value);
36			r_sum_weight += weight;
37		}
38		
39		#ifdef MODE_WIDE
40		vec4 sample_blurred_wide(ivec2 p_pos, vec2 p_coord) {
41			vec4 ssil_value = textureLodOffset(source_ssil, vec2(p_coord), 0.0, ivec2(0, 0));
42			vec4 ssil_valueL = textureLodOffset(source_ssil, vec2(p_coord), 0.0, ivec2(-2, 0));
43			vec4 ssil_valueT = textureLodOffset(source_ssil, vec2(p_coord), 0.0, ivec2(0, -2));
44			vec4 ssil_valueR = textureLodOffset(source_ssil, vec2(p_coord), 0.0, ivec2(2, 0));
45			vec4 ssil_valueB = textureLodOffset(source_ssil, vec2(p_coord), 0.0, ivec2(0, 2));
46		
47			vec4 edgesLRTB = unpack_edges(imageLoad(source_edges, p_pos).r);
48			edgesLRTB.x *= unpack_edges(imageLoad(source_edges, p_pos + ivec2(-2, 0)).r).y;
49			edgesLRTB.z *= unpack_edges(imageLoad(source_edges, p_pos + ivec2(0, -2)).r).w;
50			edgesLRTB.y *= unpack_edges(imageLoad(source_edges, p_pos + ivec2(2, 0)).r).x;
51			edgesLRTB.w *= unpack_edges(imageLoad(source_edges, p_pos + ivec2(0, 2)).r).z;
52		
53			float sum_weight = 0.8;
54			vec4 sum = ssil_value * sum_weight;
55		
56			add_sample(ssil_valueL, edgesLRTB.x, sum, sum_weight);
57			add_sample(ssil_valueR, edgesLRTB.y, sum, sum_weight);
58			add_sample(ssil_valueT, edgesLRTB.z, sum, sum_weight);
59			add_sample(ssil_valueB, edgesLRTB.w, sum, sum_weight);
60		
61			vec4 ssil_avg = sum / sum_weight;
62		
63			ssil_value = ssil_avg;
64		
65			return ssil_value;
66		}
67		#endif
68		
69		#ifdef MODE_SMART
70		vec4 sample_blurred(ivec2 p_pos, vec2 p_coord) {
71			vec4 vC = textureLodOffset(source_ssil, vec2(p_coord), 0.0, ivec2(0, 0));
72			vec4 vL = textureLodOffset(source_ssil, vec2(p_coord), 0.0, ivec2(-1, 0));
73			vec4 vT = textureLodOffset(source_ssil, vec2(p_coord), 0.0, ivec2(0, -1));
74			vec4 vR = textureLodOffset(source_ssil, vec2(p_coord), 0.0, ivec2(1, 0));
75			vec4 vB = textureLodOffset(source_ssil, vec2(p_coord), 0.0, ivec2(0, 1));
76		
77			float packed_edges = imageLoad(source_edges, p_pos).r;
78			vec4 edgesLRTB = unpack_edges(packed_edges);
79		
80			float sum_weight = 0.5;
81			vec4 sum = vC * sum_weight;
82		
83			add_sample(vL, edgesLRTB.x, sum, sum_weight);
84			add_sample(vR, edgesLRTB.y, sum, sum_weight);
85			add_sample(vT, edgesLRTB.z, sum, sum_weight);
86			add_sample(vB, edgesLRTB.w, sum, sum_weight);
87		
88			vec4 ssil_avg = sum / sum_weight;
89		
90			vec4 ssil_value = ssil_avg;
91		
92			return ssil_value;
93		}
94		#endif
95		
96		void main() {
97			// Pixel being shaded
98			ivec2 ssC = ivec2(gl_GlobalInvocationID.xy);
99		
100		#ifdef MODE_NON_SMART
101		
102			vec2 half_pixel = params.half_screen_pixel_size * 0.5;
103		
104			vec2 uv = (vec2(gl_GlobalInvocationID.xy) + vec2(0.5, 0.5)) * params.half_screen_pixel_size;
105		
106			vec4 center = textureLod(source_ssil, uv, 0.0);
107		
108			vec4 value = textureLod(source_ssil, vec2(uv + vec2(-half_pixel.x * 3, -half_pixel.y)), 0.0) * 0.2;
109			value += textureLod(source_ssil, vec2(uv + vec2(+half_pixel.x, -half_pixel.y * 3)), 0.0) * 0.2;
110			value += textureLod(source_ssil, vec2(uv + vec2(-half_pixel.x, +half_pixel.y * 3)), 0.0) * 0.2;
111			value += textureLod(source_ssil, vec2(uv + vec2(+half_pixel.x * 3, +half_pixel.y)), 0.0) * 0.2;
112		
113			vec4 sampled = value + center * 0.2;
114		
115		#else
116		#ifdef MODE_SMART
117			vec4 sampled = sample_blurred(ssC, (vec2(gl_GlobalInvocationID.xy) + vec2(0.5, 0.5)) * params.half_screen_pixel_size);
118		#else // MODE_WIDE
119			vec4 sampled = sample_blurred_wide(ssC, (vec2(gl_GlobalInvocationID.xy) + vec2(0.5, 0.5)) * params.half_screen_pixel_size);
120		#endif
121		#endif // MODE_NON_SMART
122			imageStore(dest_image, ssC, sampled);
123		}
124		
125		
          RDShaderFile                                    RSRC