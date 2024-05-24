RSRC                    RDShaderFile            ��������                                                  resource_local_to_scene    resource_name    bytecode_vertex    bytecode_fragment    bytecode_tesselation_control     bytecode_tesselation_evaluation    bytecode_compute    compile_error_vertex    compile_error_fragment "   compile_error_tesselation_control %   compile_error_tesselation_evaluation    compile_error_compute    script 
   _versions    base_error           local://RDShaderSPIRV_4ucp7 ;         local://RDShaderFile_o0opb ~         RDShaderSPIRV            Failed parse:
ERROR: 0:110: 'kernel_size' : undeclared identifier 
ERROR: 0:110: '' : compilation terminated 
ERROR: 2 compilation errors.  No code generated.




Stage 'compute' source code: 

1		
2		#version 450
3		
4		#
5		
6		layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
7		
8		#ifdef USE_25_SAMPLES
9		const int kernel_size = 13;
10		
11		const vec2 kernel[kernel_size] = vec2[](
12				vec2(0.530605, 0.0),
13				vec2(0.0211412, 0.0208333),
14				vec2(0.0402784, 0.0833333),
15				vec2(0.0493588, 0.1875),
16				vec2(0.0410172, 0.333333),
17				vec2(0.0263642, 0.520833),
18				vec2(0.017924, 0.75),
19				vec2(0.0128496, 1.02083),
20				vec2(0.0094389, 1.33333),
21				vec2(0.00700976, 1.6875),
22				vec2(0.00500364, 2.08333),
23				vec2(0.00333804, 2.52083),
24				vec2(0.000973794, 3.0));
25		
26		const vec4 skin_kernel[kernel_size] = vec4[](
27				vec4(0.530605, 0.613514, 0.739601, 0),
28				vec4(0.0211412, 0.0459286, 0.0378196, 0.0208333),
29				vec4(0.0402784, 0.0657244, 0.04631, 0.0833333),
30				vec4(0.0493588, 0.0367726, 0.0219485, 0.1875),
31				vec4(0.0410172, 0.0199899, 0.0118481, 0.333333),
32				vec4(0.0263642, 0.0119715, 0.00684598, 0.520833),
33				vec4(0.017924, 0.00711691, 0.00347194, 0.75),
34				vec4(0.0128496, 0.00356329, 0.00132016, 1.02083),
35				vec4(0.0094389, 0.00139119, 0.000416598, 1.33333),
36				vec4(0.00700976, 0.00049366, 0.000151938, 1.6875),
37				vec4(0.00500364, 0.00020094, 5.28848e-005, 2.08333),
38				vec4(0.00333804, 7.85443e-005, 1.2945e-005, 2.52083),
39				vec4(0.000973794, 1.11862e-005, 9.43437e-007, 3));
40		
41		#endif //USE_25_SAMPLES
42		
43		#ifdef USE_17_SAMPLES
44		const int kernel_size = 9;
45		const vec2 kernel[kernel_size] = vec2[](
46				vec2(0.536343, 0.0),
47				vec2(0.0324462, 0.03125),
48				vec2(0.0582416, 0.125),
49				vec2(0.0571056, 0.28125),
50				vec2(0.0347317, 0.5),
51				vec2(0.0216301, 0.78125),
52				vec2(0.0144609, 1.125),
53				vec2(0.0100386, 1.53125),
54				vec2(0.00317394, 2.0));
55		
56		const vec4 skin_kernel[kernel_size] = vec4[](
57				vec4(0.536343, 0.624624, 0.748867, 0),
58				vec4(0.0324462, 0.0656718, 0.0532821, 0.03125),
59				vec4(0.0582416, 0.0659959, 0.0411329, 0.125),
60				vec4(0.0571056, 0.0287432, 0.0172844, 0.28125),
61				vec4(0.0347317, 0.0151085, 0.00871983, 0.5),
62				vec4(0.0216301, 0.00794618, 0.00376991, 0.78125),
63				vec4(0.0144609, 0.00317269, 0.00106399, 1.125),
64				vec4(0.0100386, 0.000914679, 0.000275702, 1.53125),
65				vec4(0.00317394, 0.000134823, 3.77269e-005, 2));
66		#endif //USE_17_SAMPLES
67		
68		#ifdef USE_11_SAMPLES
69		const int kernel_size = 6;
70		const vec2 kernel[kernel_size] = vec2[](
71				vec2(0.560479, 0.0),
72				vec2(0.0771802, 0.08),
73				vec2(0.0821904, 0.32),
74				vec2(0.03639, 0.72),
75				vec2(0.0192831, 1.28),
76				vec2(0.00471691, 2.0));
77		
78		const vec4 skin_kernel[kernel_size] = vec4[](
79		
80				vec4(0.560479, 0.669086, 0.784728, 0),
81				vec4(0.0771802, 0.113491, 0.0793803, 0.08),
82				vec4(0.0821904, 0.0358608, 0.0209261, 0.32),
83				vec4(0.03639, 0.0130999, 0.00643685, 0.72),
84				vec4(0.0192831, 0.00282018, 0.00084214, 1.28),
85				vec4(0.00471691, 0.000184771, 5.07565e-005, 2));
86		
87		#endif //USE_11_SAMPLES
88		
89		layout(push_constant, std430) uniform Params {
90			ivec2 screen_size;
91			float camera_z_far;
92			float camera_z_near;
93		
94			bool vertical;
95			bool orthogonal;
96			float unit_size;
97			float scale;
98		
99			float depth_scale;
100			uint pad[3];
101		}
102		params;
103		
104		layout(set = 0, binding = 0) uniform sampler2D source_image;
105		layout(rgba16f, set = 1, binding = 0) uniform restrict writeonly image2D dest_image;
106		layout(set = 2, binding = 0) uniform sampler2D source_depth;
107		
108		void do_filter(inout vec3 color_accum, inout vec3 divisor, vec2 uv, vec2 step, bool p_skin) {
109			// Accumulate the other samples:
110			for (int i = 1; i < kernel_size; i++) {
111				// Fetch color and depth for current sample:
112				vec2 offset = uv + kernel[i].y * step;
113				vec4 color = texture(source_image, offset);
114		
115				if (abs(color.a) < 0.001) {
116					break; //mix no more
117				}
118		
119				vec3 w;
120				if (p_skin) {
121					//skin
122					w = skin_kernel[i].rgb;
123				} else {
124					w = vec3(kernel[i].x);
125				}
126		
127				color_accum += color.rgb * w;
128				divisor += w;
129			}
130		}
131		
132		void main() {
133			// Pixel being shaded
134			ivec2 ssC = ivec2(gl_GlobalInvocationID.xy);
135		
136			if (any(greaterThanEqual(ssC, params.screen_size))) { //too large, do nothing
137				return;
138			}
139		
140			vec2 uv = (vec2(ssC) + 0.5) / vec2(params.screen_size);
141		
142			// Fetch color of current pixel:
143			vec4 base_color = texture(source_image, uv);
144			float strength = abs(base_color.a);
145		
146			if (strength > 0.0) {
147				vec2 dir = params.vertical ? vec2(0.0, 1.0) : vec2(1.0, 0.0);
148		
149				// Fetch linear depth of current pixel:
150				float depth = texture(source_depth, uv).r * 2.0 - 1.0;
151				float depth_scale;
152		
153				if (params.orthogonal) {
154					depth = ((depth + (params.camera_z_far + params.camera_z_near) / (params.camera_z_far - params.camera_z_near)) * (params.camera_z_far - params.camera_z_near)) / 2.0;
155					depth_scale = params.unit_size; //remember depth is negative by default in OpenGL
156				} else {
157					depth = 2.0 * params.camera_z_near * params.camera_z_far / (params.camera_z_far + params.camera_z_near - depth * (params.camera_z_far - params.camera_z_near));
158					depth_scale = params.unit_size / depth; //remember depth is negative by default in OpenGL
159				}
160		
161				float scale = mix(params.scale, depth_scale, params.depth_scale);
162		
163				// Calculate the final step to fetch the surrounding pixels:
164				vec2 step = scale * dir;
165				step *= strength;
166				step /= 3.0;
167				// Accumulate the center sample:
168		
169				vec3 divisor;
170				bool skin = bool(base_color.a < 0.0);
171		
172				if (skin) {
173					//skin
174					divisor = skin_kernel[0].rgb;
175				} else {
176					divisor = vec3(kernel[0].x);
177				}
178		
179				vec3 color = base_color.rgb * divisor;
180		
181				do_filter(color, divisor, uv, step, skin);
182				do_filter(color, divisor, uv, -step, skin);
183		
184				base_color.rgb = color / divisor;
185			}
186		
187			imageStore(dest_image, ssC, base_color);
188		}
189		
190		
          RDShaderFile                                    RSRC