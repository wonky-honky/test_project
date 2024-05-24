RSRC                    RDShaderFile            ��������                                                  resource_local_to_scene    resource_name    bytecode_vertex    bytecode_fragment    bytecode_tesselation_control     bytecode_tesselation_evaluation    bytecode_compute    compile_error_vertex    compile_error_fragment "   compile_error_tesselation_control %   compile_error_tesselation_evaluation    compile_error_compute    script 
   _versions    base_error           local://RDShaderSPIRV_p3ul1 ;         local://RDShaderFile_w6g4t Q2         RDShaderSPIRV          d  #    0                 GLSL.std.450              	        main          #   /        �       main         base_arr         uv_interp        gl_VertexIndex    !   gl_PerVertex      !       gl_Position   !      gl_PointSize      !      gl_ClipDistance   !      gl_CullDistance   #         -   Params    -       orientation   -      projection    -      position      -      time      -      pad  	 -      luminance_multiplier      /   params  G            G        *   H  !              H  !            H  !            H  !            G  !      H  -          H  -       #       H  -             H  -      #   0   H  -      #   @   H  -      #   L   H  -      #   P   H  -      #   \   G  -           !                                         +     	        
      	            
   +          ��+          @�,              +          �?,              +          @@,              ,  
                           ;                                   ;                                  +                         !                    "      !   ;  "   #      +     $          )           +           ,   +        -   ,      +      +         .   	   -   ;  .   /   	   6               �     ;           >        =           A              =           >        =     %      Q     &   %       Q     '   %      P     (   &   '         A  )   *   #   $   >  *   (   �  8        |)  Failed parse:
ERROR: 0:35: 'SAMPLERS_BINDING_FIRST_INDEX' : undeclared identifier 
ERROR: 0:35: '' : compilation terminated 
ERROR: 2 compilation errors.  No code generated.




Stage 'fragment' source code: 

1		
2		#version 450
3		
4		#
5		
6		#ifdef USE_MULTIVIEW
7		#ifdef has_VK_KHR_multiview
8		#extension GL_EXT_multiview : enable
9		#define ViewIndex gl_ViewIndex
10		#else // has_VK_KHR_multiview
11		// !BAS! This needs to become an input once we implement our fallback!
12		#define ViewIndex 0
13		#endif // has_VK_KHR_multiview
14		#else // USE_MULTIVIEW
15		// Set to zero, not supported in non stereo
16		#define ViewIndex 0
17		#endif //USE_MULTIVIEW
18		
19		#define M_PI 3.14159265359
20		#define MAX_VIEWS 2
21		
22		layout(location = 0) in vec2 uv_interp;
23		
24		layout(push_constant, std430) uniform Params {
25			mat3 orientation;
26			vec4 projection; // only applicable if not multiview
27			vec3 position;
28			float time;
29			vec3 pad;
30			float luminance_multiplier;
31		}
32		params;
33		
34		
35		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 0) uniform sampler SAMPLER_NEAREST_CLAMP;
36		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 1) uniform sampler SAMPLER_LINEAR_CLAMP;
37		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 2) uniform sampler SAMPLER_NEAREST_WITH_MIPMAPS_CLAMP;
38		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 3) uniform sampler SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP;
39		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 4) uniform sampler SAMPLER_NEAREST_WITH_MIPMAPS_ANISOTROPIC_CLAMP;
40		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 5) uniform sampler SAMPLER_LINEAR_WITH_MIPMAPS_ANISOTROPIC_CLAMP;
41		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 6) uniform sampler SAMPLER_NEAREST_REPEAT;
42		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 7) uniform sampler SAMPLER_LINEAR_REPEAT;
43		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 8) uniform sampler SAMPLER_NEAREST_WITH_MIPMAPS_REPEAT;
44		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 9) uniform sampler SAMPLER_LINEAR_WITH_MIPMAPS_REPEAT;
45		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 10) uniform sampler SAMPLER_NEAREST_WITH_MIPMAPS_ANISOTROPIC_REPEAT;
46		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 11) uniform sampler SAMPLER_LINEAR_WITH_MIPMAPS_ANISOTROPIC_REPEAT;
47		
48		layout(set = 0, binding = 1, std430) restrict readonly buffer GlobalShaderUniformData {
49			vec4 data[];
50		}
51		global_shader_uniforms;
52		
53		layout(set = 0, binding = 2, std140) uniform SkySceneData {
54			mat4 combined_reprojection[2];
55			mat4 view_inv_projections[2];
56			vec4 view_eye_offsets[2];
57		
58			bool volumetric_fog_enabled; // 4 - 4
59			float volumetric_fog_inv_length; // 4 - 8
60			float volumetric_fog_detail_spread; // 4 - 12
61			float volumetric_fog_sky_affect; // 4 - 16
62		
63			bool fog_enabled; // 4 - 20
64			float fog_sky_affect; // 4 - 24
65			float fog_density; // 4 - 28
66			float fog_sun_scatter; // 4 - 32
67		
68			vec3 fog_light_color; // 12 - 44
69			float fog_aerial_perspective; // 4 - 48
70		
71			float z_far; // 4 - 52
72			uint directional_light_count; // 4 - 56
73			uint pad1; // 4 - 60
74			uint pad2; // 4 - 64
75		}
76		sky_scene_data;
77		
78		struct DirectionalLightData {
79			vec4 direction_energy;
80			vec4 color_size;
81			bool enabled;
82		};
83		
84		layout(set = 0, binding = 3, std140) uniform DirectionalLights {
85			DirectionalLightData data[MAX_DIRECTIONAL_LIGHT_DATA_STRUCTS];
86		}
87		directional_lights;
88		
89		#ifdef MATERIAL_UNIFORMS_USED
90		layout(set = 1, binding = 0, std140) uniform MaterialUniforms{
91		#MATERIAL_UNIFORMS
92		} material;
93		#endif
94		
95		layout(set = 2, binding = 0) uniform textureCube radiance;
96		#ifdef USE_CUBEMAP_PASS
97		layout(set = 2, binding = 1) uniform textureCube half_res;
98		layout(set = 2, binding = 2) uniform textureCube quarter_res;
99		#elif defined(USE_MULTIVIEW)
100		layout(set = 2, binding = 1) uniform texture2DArray half_res;
101		layout(set = 2, binding = 2) uniform texture2DArray quarter_res;
102		#else
103		layout(set = 2, binding = 1) uniform texture2D half_res;
104		layout(set = 2, binding = 2) uniform texture2D quarter_res;
105		#endif
106		
107		layout(set = 3, binding = 0) uniform texture3D volumetric_fog_texture;
108		
109		#ifdef USE_CUBEMAP_PASS
110		#define AT_CUBEMAP_PASS true
111		#else
112		#define AT_CUBEMAP_PASS false
113		#endif
114		
115		#ifdef USE_HALF_RES_PASS
116		#define AT_HALF_RES_PASS true
117		#else
118		#define AT_HALF_RES_PASS false
119		#endif
120		
121		#ifdef USE_QUARTER_RES_PASS
122		#define AT_QUARTER_RES_PASS true
123		#else
124		#define AT_QUARTER_RES_PASS false
125		#endif
126		
127		#GLOBALS
128		
129		layout(location = 0) out vec4 frag_color;
130		
131		#ifdef USE_DEBANDING
132		// https://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare
133		vec3 interleaved_gradient_noise(vec2 pos) {
134			const vec3 magic = vec3(0.06711056f, 0.00583715f, 52.9829189f);
135			float res = fract(magic.z * fract(dot(pos, magic.xy))) * 2.0 - 1.0;
136			return vec3(res, -res, res) / 255.0;
137		}
138		#endif
139		
140		vec4 volumetric_fog_process(vec2 screen_uv) {
141		#ifdef USE_MULTIVIEW
142			vec4 reprojected = sky_scene_data.combined_reprojection[ViewIndex] * (vec4(screen_uv * 2.0 - 1.0, 1.0, 1.0) * sky_scene_data.z_far);
143			vec3 fog_pos = vec3(reprojected.xy / reprojected.w, 1.0) * 0.5 + 0.5;
144		#else
145			vec3 fog_pos = vec3(screen_uv, 1.0);
146		#endif
147		
148			return texture(sampler3D(volumetric_fog_texture, SAMPLER_LINEAR_CLAMP), fog_pos);
149		}
150		
151		vec4 fog_process(vec3 view, vec3 sky_color) {
152			vec3 fog_color = mix(sky_scene_data.fog_light_color, sky_color, sky_scene_data.fog_aerial_perspective);
153		
154			if (sky_scene_data.fog_sun_scatter > 0.001) {
155				vec4 sun_scatter = vec4(0.0);
156				float sun_total = 0.0;
157				for (uint i = 0; i < sky_scene_data.directional_light_count; i++) {
158					vec3 light_color = directional_lights.data[i].color_size.xyz * directional_lights.data[i].direction_energy.w;
159					float light_amount = pow(max(dot(view, directional_lights.data[i].direction_energy.xyz), 0.0), 8.0);
160					fog_color += light_color * light_amount * sky_scene_data.fog_sun_scatter;
161				}
162			}
163		
164			return vec4(fog_color, 1.0);
165		}
166		
167		void main() {
168			vec3 cube_normal;
169		#ifdef USE_MULTIVIEW
170			// In multiview our projection matrices will contain positional and rotational offsets that we need to properly unproject.
171			vec4 unproject = vec4(uv_interp.x, -uv_interp.y, 1.0, 1.0);
172			vec4 unprojected = sky_scene_data.view_inv_projections[ViewIndex] * unproject;
173			cube_normal = unprojected.xyz / unprojected.w;
174			cube_normal += sky_scene_data.view_eye_offsets[ViewIndex].xyz;
175		#else
176			cube_normal.z = -1.0;
177			cube_normal.x = (cube_normal.z * (-uv_interp.x - params.projection.x)) / params.projection.y;
178			cube_normal.y = -(cube_normal.z * (-uv_interp.y - params.projection.z)) / params.projection.w;
179		#endif
180			cube_normal = mat3(params.orientation) * cube_normal;
181			cube_normal = normalize(cube_normal);
182		
183			vec2 uv = uv_interp * 0.5 + 0.5;
184		
185			vec2 panorama_coords = vec2(atan(cube_normal.x, -cube_normal.z), acos(cube_normal.y));
186		
187			if (panorama_coords.x < 0.0) {
188				panorama_coords.x += M_PI * 2.0;
189			}
190		
191			panorama_coords /= vec2(M_PI * 2.0, M_PI);
192		
193			vec3 color = vec3(0.0, 0.0, 0.0);
194			float alpha = 1.0; // Only available to subpasses
195			vec4 half_res_color = vec4(1.0);
196			vec4 quarter_res_color = vec4(1.0);
197			vec4 custom_fog = vec4(0.0);
198		
199		#ifdef USE_CUBEMAP_PASS
200		
201		#ifdef USES_HALF_RES_COLOR
202			half_res_color = texture(samplerCube(half_res, SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP), cube_normal) / params.luminance_multiplier;
203		#endif
204		#ifdef USES_QUARTER_RES_COLOR
205			quarter_res_color = texture(samplerCube(quarter_res, SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP), cube_normal) / params.luminance_multiplier;
206		#endif
207		
208		#else
209		
210		#ifdef USES_HALF_RES_COLOR
211		#ifdef USE_MULTIVIEW
212			half_res_color = textureLod(sampler2DArray(half_res, SAMPLER_LINEAR_CLAMP), vec3(uv, ViewIndex), 0.0) / params.luminance_multiplier;
213		#else
214			half_res_color = textureLod(sampler2D(half_res, SAMPLER_LINEAR_CLAMP), uv, 0.0) / params.luminance_multiplier;
215		#endif // USE_MULTIVIEW
216		#endif // USES_HALF_RES_COLOR
217		
218		#ifdef USES_QUARTER_RES_COLOR
219		#ifdef USE_MULTIVIEW
220			quarter_res_color = textureLod(sampler2DArray(quarter_res, SAMPLER_LINEAR_CLAMP), vec3(uv, ViewIndex), 0.0) / params.luminance_multiplier;
221		#else
222			quarter_res_color = textureLod(sampler2D(quarter_res, SAMPLER_LINEAR_CLAMP), uv, 0.0) / params.luminance_multiplier;
223		#endif // USE_MULTIVIEW
224		#endif // USES_QUARTER_RES_COLOR
225		
226		#endif //USE_CUBEMAP_PASS
227		
228			{
229		
230		#CODE : SKY
231		
232			}
233		
234			frag_color.rgb = color;
235			frag_color.a = alpha;
236		
237			// For mobile renderer we're multiplying by 0.5 as we're using a UNORM buffer.
238			// For both mobile and clustered, we also bake in the exposure value for the environment and camera.
239			frag_color.rgb = frag_color.rgb * params.luminance_multiplier;
240		
241		#if !defined(DISABLE_FOG) && !defined(USE_CUBEMAP_PASS)
242		
243			// Draw "fixed" fog before volumetric fog to ensure volumetric fog can appear in front of the sky.
244			if (sky_scene_data.fog_enabled) {
245				vec4 fog = fog_process(cube_normal, frag_color.rgb);
246				frag_color.rgb = mix(frag_color.rgb, fog.rgb, fog.a * sky_scene_data.fog_sky_affect);
247			}
248		
249			if (sky_scene_data.volumetric_fog_enabled) {
250				vec4 fog = volumetric_fog_process(uv);
251				frag_color.rgb = mix(frag_color.rgb, fog.rgb, fog.a * sky_scene_data.volumetric_fog_sky_affect);
252			}
253		
254			if (custom_fog.a > 0.0) {
255				frag_color.rgb = mix(frag_color.rgb, custom_fog.rgb, custom_fog.a);
256			}
257		
258		#endif // DISABLE_FOG
259		
260			// Blending is disabled for Sky, so alpha doesn't blend.
261			// Alpha is used for subsurface scattering so make sure it doesn't get applied to Sky.
262			if (!AT_CUBEMAP_PASS && !AT_HALF_RES_PASS && !AT_QUARTER_RES_PASS) {
263				frag_color.a = 0.0;
264			}
265		
266		#ifdef USE_DEBANDING
267			frag_color.rgb += interleaved_gradient_noise(gl_FragCoord.xy) * params.luminance_multiplier;
268		#endif
269		}
270		
271		
          RDShaderFile                                    RSRC