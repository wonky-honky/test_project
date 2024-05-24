RSRC                    RDShaderFile            ��������                                                  resource_local_to_scene    resource_name    bytecode_vertex    bytecode_fragment    bytecode_tesselation_control     bytecode_tesselation_evaluation    bytecode_compute    compile_error_vertex    compile_error_fragment "   compile_error_tesselation_control %   compile_error_tesselation_evaluation    compile_error_compute    script 
   _versions    base_error           local://RDShaderSPIRV_dbbob ;         local://RDShaderFile_3catp �?         RDShaderSPIRV          L=  Failed parse:
ERROR: 0:104: 'SAMPLERS_BINDING_FIRST_INDEX' : undeclared identifier 
ERROR: 0:104: '' : compilation terminated 
ERROR: 2 compilation errors.  No code generated.




Stage 'compute' source code: 

1		
2		#version 450
3		
4		#
5		
6		layout(local_size_x = 4, local_size_y = 4, local_size_z = 4) in;
7		
8		#define DENSITY_SCALE 1024.0
9		
10		
11		#define CLUSTER_COUNTER_SHIFT 20
12		#define CLUSTER_POINTER_MASK ((1 << CLUSTER_COUNTER_SHIFT) - 1)
13		#define CLUSTER_COUNTER_MASK 0xfff
14		
15		
16		#define LIGHT_BAKE_DISABLED 0
17		#define LIGHT_BAKE_STATIC 1
18		#define LIGHT_BAKE_DYNAMIC 2
19		
20		struct LightData { //this structure needs to be as packed as possible
21			highp vec3 position;
22			highp float inv_radius;
23		
24			mediump vec3 direction;
25			highp float size;
26		
27			mediump vec3 color;
28			mediump float attenuation;
29		
30			mediump float cone_attenuation;
31			mediump float cone_angle;
32			mediump float specular_amount;
33			mediump float shadow_opacity;
34		
35			highp vec4 atlas_rect; // rect in the shadow atlas
36			highp mat4 shadow_matrix;
37			highp float shadow_bias;
38			highp float shadow_normal_bias;
39			highp float transmittance_bias;
40			highp float soft_shadow_size; // for spot, it's the size in uv coordinates of the light, for omni it's the span angle
41			highp float soft_shadow_scale; // scales the shadow kernel for blurrier shadows
42			uint mask;
43			mediump float volumetric_fog_energy;
44			uint bake_mode;
45			highp vec4 projector_rect; //projector rect in srgb decal atlas
46		};
47		
48		#define REFLECTION_AMBIENT_DISABLED 0
49		#define REFLECTION_AMBIENT_ENVIRONMENT 1
50		#define REFLECTION_AMBIENT_COLOR 2
51		
52		struct ReflectionData {
53			highp vec3 box_extents;
54			mediump float index;
55			highp vec3 box_offset;
56			uint mask;
57			mediump vec3 ambient; // ambient color
58			mediump float intensity;
59			bool exterior;
60			bool box_project;
61			uint ambient_mode;
62			float exposure_normalization;
63			//0-8 is intensity,8-9 is ambient, mode
64			highp mat4 local_matrix; // up to here for spot and omni, rest is for directional
65			// notes: for ambientblend, use distance to edge to blend between already existing global environment
66		};
67		
68		struct DirectionalLightData {
69			mediump vec3 direction;
70			highp float energy; // needs to be highp to avoid NaNs being created with high energy values (i.e. when using physical light units and over-exposing the image)
71			mediump vec3 color;
72			mediump float size;
73			mediump float specular;
74			uint mask;
75			highp float softshadow_angle;
76			highp float soft_shadow_scale;
77			bool blend_splits;
78			mediump float shadow_opacity;
79			highp float fade_from;
80			highp float fade_to;
81			uvec2 pad;
82			uint bake_mode;
83			mediump float volumetric_fog_energy;
84			highp vec4 shadow_bias;
85			highp vec4 shadow_normal_bias;
86			highp vec4 shadow_transmittance_bias;
87			highp vec4 shadow_z_range;
88			highp vec4 shadow_range_begin;
89			highp vec4 shadow_split_offsets;
90			highp mat4 shadow_matrix1;
91			highp mat4 shadow_matrix2;
92			highp mat4 shadow_matrix3;
93			highp mat4 shadow_matrix4;
94			highp vec2 uv_scale1;
95			highp vec2 uv_scale2;
96			highp vec2 uv_scale3;
97			highp vec2 uv_scale4;
98		};
99		
100		
101		#define M_PI 3.14159265359
102		
103		
104		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 0) uniform sampler SAMPLER_NEAREST_CLAMP;
105		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 1) uniform sampler SAMPLER_LINEAR_CLAMP;
106		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 2) uniform sampler SAMPLER_NEAREST_WITH_MIPMAPS_CLAMP;
107		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 3) uniform sampler SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP;
108		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 4) uniform sampler SAMPLER_NEAREST_WITH_MIPMAPS_ANISOTROPIC_CLAMP;
109		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 5) uniform sampler SAMPLER_LINEAR_WITH_MIPMAPS_ANISOTROPIC_CLAMP;
110		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 6) uniform sampler SAMPLER_NEAREST_REPEAT;
111		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 7) uniform sampler SAMPLER_LINEAR_REPEAT;
112		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 8) uniform sampler SAMPLER_NEAREST_WITH_MIPMAPS_REPEAT;
113		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 9) uniform sampler SAMPLER_LINEAR_WITH_MIPMAPS_REPEAT;
114		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 10) uniform sampler SAMPLER_NEAREST_WITH_MIPMAPS_ANISOTROPIC_REPEAT;
115		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 11) uniform sampler SAMPLER_LINEAR_WITH_MIPMAPS_ANISOTROPIC_REPEAT;
116		
117		layout(set = 0, binding = 2, std430) restrict readonly buffer GlobalShaderUniformData {
118			vec4 data[];
119		}
120		global_shader_uniforms;
121		
122		layout(push_constant, std430) uniform Params {
123			vec3 position;
124			float pad;
125		
126			vec3 size;
127			float pad2;
128		
129			ivec3 corner;
130			uint shape;
131		
132			mat4 transform;
133		}
134		params;
135		
136		#ifdef MOLTENVK_USED
137		layout(set = 1, binding = 1) volatile buffer emissive_only_map_buffer {
138			uint emissive_only_map[];
139		};
140		#else
141		layout(r32ui, set = 1, binding = 1) uniform volatile uimage3D emissive_only_map;
142		#endif
143		
144		layout(set = 1, binding = 2, std140) uniform SceneParams {
145			vec2 fog_frustum_size_begin;
146			vec2 fog_frustum_size_end;
147		
148			float fog_frustum_end;
149			float z_near; //
150			float z_far; //
151			float time;
152		
153			ivec3 fog_volume_size;
154			uint directional_light_count; //
155		
156			bool use_temporal_reprojection;
157			uint temporal_frame;
158			float detail_spread;
159			float temporal_blend;
160		
161			mat4 to_prev_view;
162			mat4 transform;
163		}
164		scene_params;
165		
166		#ifdef MOLTENVK_USED
167		layout(set = 1, binding = 3) volatile buffer density_only_map_buffer {
168			uint density_only_map[];
169		};
170		layout(set = 1, binding = 4) volatile buffer light_only_map_buffer {
171			uint light_only_map[];
172		};
173		#else
174		layout(r32ui, set = 1, binding = 3) uniform volatile uimage3D density_only_map;
175		layout(r32ui, set = 1, binding = 4) uniform volatile uimage3D light_only_map;
176		#endif
177		
178		#ifdef MATERIAL_UNIFORMS_USED
179		layout(set = 2, binding = 0, std140) uniform MaterialUniforms{
180		#MATERIAL_UNIFORMS
181		} material;
182		#endif
183		
184		#GLOBALS
185		
186		float get_depth_at_pos(float cell_depth_size, int z) {
187			float d = float(z) * cell_depth_size + cell_depth_size * 0.5; //center of voxels
188			d = pow(d, scene_params.detail_spread);
189			return scene_params.fog_frustum_end * d;
190		}
191		
192		#define TEMPORAL_FRAMES 16
193		
194		const vec3 halton_map[TEMPORAL_FRAMES] = vec3[](
195				vec3(0.5, 0.33333333, 0.2),
196				vec3(0.25, 0.66666667, 0.4),
197				vec3(0.75, 0.11111111, 0.6),
198				vec3(0.125, 0.44444444, 0.8),
199				vec3(0.625, 0.77777778, 0.04),
200				vec3(0.375, 0.22222222, 0.24),
201				vec3(0.875, 0.55555556, 0.44),
202				vec3(0.0625, 0.88888889, 0.64),
203				vec3(0.5625, 0.03703704, 0.84),
204				vec3(0.3125, 0.37037037, 0.08),
205				vec3(0.8125, 0.7037037, 0.28),
206				vec3(0.1875, 0.14814815, 0.48),
207				vec3(0.6875, 0.48148148, 0.68),
208				vec3(0.4375, 0.81481481, 0.88),
209				vec3(0.9375, 0.25925926, 0.12),
210				vec3(0.03125, 0.59259259, 0.32));
211		
212		void main() {
213			vec3 fog_cell_size = 1.0 / vec3(scene_params.fog_volume_size);
214		
215			ivec3 pos = ivec3(gl_GlobalInvocationID.xyz) + params.corner;
216			if (any(greaterThanEqual(pos, scene_params.fog_volume_size))) {
217				return; //do not compute
218			}
219		#ifdef MOLTENVK_USED
220			uint lpos = pos.z * scene_params.fog_volume_size.x * scene_params.fog_volume_size.y + pos.y * scene_params.fog_volume_size.x + pos.x;
221		#endif
222		
223			vec3 posf = vec3(pos);
224		
225			vec3 fog_unit_pos = posf * fog_cell_size + fog_cell_size * 0.5; //center of voxels
226			fog_unit_pos.z = pow(fog_unit_pos.z, scene_params.detail_spread);
227		
228			vec3 view_pos;
229			view_pos.xy = (fog_unit_pos.xy * 2.0 - 1.0) * mix(scene_params.fog_frustum_size_begin, scene_params.fog_frustum_size_end, vec2(fog_unit_pos.z));
230			view_pos.z = -scene_params.fog_frustum_end * fog_unit_pos.z;
231			view_pos.y = -view_pos.y;
232		
233			if (scene_params.use_temporal_reprojection) {
234				vec3 prev_view = (scene_params.to_prev_view * vec4(view_pos, 1.0)).xyz;
235				//undo transform into prev view
236				prev_view.y = -prev_view.y;
237				//z back to unit size
238				prev_view.z /= -scene_params.fog_frustum_end;
239				//xy back to unit size
240				prev_view.xy /= mix(scene_params.fog_frustum_size_begin, scene_params.fog_frustum_size_end, vec2(prev_view.z));
241				prev_view.xy = prev_view.xy * 0.5 + 0.5;
242				//z back to unspread value
243				prev_view.z = pow(prev_view.z, 1.0 / scene_params.detail_spread);
244		
245				if (all(greaterThan(prev_view, vec3(0.0))) && all(lessThan(prev_view, vec3(1.0)))) {
246					//reprojectinon fits
247					// Since we can reproject, now we must jitter the current view pos.
248					// This is done here because cells that can't reproject should not jitter.
249		
250					fog_unit_pos = posf * fog_cell_size + fog_cell_size * halton_map[scene_params.temporal_frame]; //center of voxels, offset by halton table
251					fog_unit_pos.z = pow(fog_unit_pos.z, scene_params.detail_spread);
252		
253					view_pos.xy = (fog_unit_pos.xy * 2.0 - 1.0) * mix(scene_params.fog_frustum_size_begin, scene_params.fog_frustum_size_end, vec2(fog_unit_pos.z));
254					view_pos.z = -scene_params.fog_frustum_end * fog_unit_pos.z;
255					view_pos.y = -view_pos.y;
256				}
257			}
258		
259			float density = 0.0;
260			vec3 emission = vec3(0.0);
261			vec3 albedo = vec3(0.0);
262		
263			float cell_depth_size = abs(view_pos.z - get_depth_at_pos(fog_cell_size.z, pos.z + 1));
264		
265			vec4 world = scene_params.transform * vec4(view_pos, 1.0);
266			world.xyz /= world.w;
267		
268			vec3 uvw = fog_unit_pos;
269		
270			vec4 local_pos = params.transform * world;
271			local_pos.xyz /= local_pos.w;
272		
273			vec3 half_size = params.size / 2.0;
274			float sdf = -1.0;
275			if (params.shape == 0) {
276				// Ellipsoid
277				// https://www.shadertoy.com/view/tdS3DG
278				float k0 = length(local_pos.xyz / half_size);
279				float k1 = length(local_pos.xyz / (half_size * half_size));
280				sdf = k0 * (k0 - 1.0) / k1;
281			} else if (params.shape == 1) {
282				// Cone
283				// https://iquilezles.org/www/articles/distfunctions/distfunctions.htm
284		
285				// Compute the cone angle automatically to fit within the volume's size.
286				float inv_height = 1.0 / max(0.001, half_size.y);
287				float radius = 1.0 / max(0.001, (min(half_size.x, half_size.z) * 0.5));
288				float hypotenuse = sqrt(radius * radius + inv_height * inv_height);
289				float rsin = radius / hypotenuse;
290				float rcos = inv_height / hypotenuse;
291				vec2 c = vec2(rsin, rcos);
292		
293				float q = length(local_pos.xz);
294				sdf = max(dot(c, vec2(q, local_pos.y - half_size.y)), -half_size.y - local_pos.y);
295			} else if (params.shape == 2) {
296				// Cylinder
297				// https://iquilezles.org/www/articles/distfunctions/distfunctions.htm
298				vec2 d = abs(vec2(length(local_pos.xz), local_pos.y)) - vec2(min(half_size.x, half_size.z), half_size.y);
299				sdf = min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
300			} else if (params.shape == 3) {
301				// Box
302				// https://iquilezles.org/www/articles/distfunctions/distfunctions.htm
303				vec3 q = abs(local_pos.xyz) - half_size;
304				sdf = length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
305			}
306		
307			float cull_mask = 1.0; //used to cull cells that do not contribute
308			if (params.shape <= 3) {
309		#ifndef SDF_USED
310				cull_mask = 1.0 - smoothstep(-0.1, 0.0, sdf);
311		#endif
312				uvw = clamp((local_pos.xyz + half_size) / params.size, 0.0, 1.0);
313			}
314		
315			if (cull_mask > 0.0) {
316				{
317		#CODE : FOG
318				}
319		
320		#ifdef DENSITY_USED
321				density *= cull_mask;
322				if (abs(density) > 0.001) {
323					int final_density = int(density * DENSITY_SCALE);
324		#ifdef MOLTENVK_USED
325					atomicAdd(density_only_map[lpos], uint(final_density));
326		#else
327					imageAtomicAdd(density_only_map, pos, uint(final_density));
328		#endif
329		
330		#ifdef EMISSION_USED
331					{
332						emission *= clamp(density, 0.0, 1.0);
333						emission = clamp(emission, vec3(0.0), vec3(4.0));
334						// Scale to fit into R11G11B10 with a range of 0-4
335						uvec3 emission_u = uvec3(emission.r * 511.0, emission.g * 511.0, emission.b * 255.0);
336						// R and G have 11 bits each and B has 10. Then pack them into a 32 bit uint
337						uint final_emission = emission_u.r << 21 | emission_u.g << 10 | emission_u.b;
338		#ifdef MOLTENVK_USED
339						uint prev_emission = atomicAdd(emissive_only_map[lpos], final_emission);
340		#else
341						uint prev_emission = imageAtomicAdd(emissive_only_map, pos, final_emission);
342		#endif
343		
344						// Adding can lead to colors overflowing, so validate
345						uvec3 prev_emission_u = uvec3(prev_emission >> 21, (prev_emission << 11) >> 21, prev_emission % 1024);
346						uint add_emission = final_emission + prev_emission;
347						uvec3 add_emission_u = uvec3(add_emission >> 21, (add_emission << 11) >> 21, add_emission % 1024);
348		
349						bvec3 overflowing = lessThan(add_emission_u, prev_emission_u + emission_u);
350		
351						if (any(overflowing)) {
352							uvec3 overflow_factor = mix(uvec3(0), uvec3(2047 << 21, 2047 << 10, 1023), overflowing);
353							uint force_max = overflow_factor.r | overflow_factor.g | overflow_factor.b;
354		#ifdef MOLTENVK_USED
355							atomicOr(emissive_only_map[lpos], force_max);
356		#else
357							imageAtomicOr(emissive_only_map, pos, force_max);
358		#endif
359						}
360					}
361		#endif
362		#ifdef ALBEDO_USED
363					{
364						vec3 scattering = albedo * clamp(density, 0.0, 1.0);
365						scattering = clamp(scattering, vec3(0.0), vec3(1.0));
366						uvec3 scattering_u = uvec3(scattering.r * 2047.0, scattering.g * 2047.0, scattering.b * 1023.0);
367						// R and G have 11 bits each and B has 10. Then pack them into a 32 bit uint
368						uint final_scattering = scattering_u.r << 21 | scattering_u.g << 10 | scattering_u.b;
369		#ifdef MOLTENVK_USED
370						uint prev_scattering = atomicAdd(light_only_map[lpos], final_scattering);
371		#else
372						uint prev_scattering = imageAtomicAdd(light_only_map, pos, final_scattering);
373		#endif
374		
375						// Adding can lead to colors overflowing, so validate
376						uvec3 prev_scattering_u = uvec3(prev_scattering >> 21, (prev_scattering << 11) >> 21, prev_scattering % 1024);
377						uint add_scattering = final_scattering + prev_scattering;
378						uvec3 add_scattering_u = uvec3(add_scattering >> 21, (add_scattering << 11) >> 21, add_scattering % 1024);
379		
380						bvec3 overflowing = lessThan(add_scattering_u, prev_scattering_u + scattering_u);
381		
382						if (any(overflowing)) {
383							uvec3 overflow_factor = mix(uvec3(0), uvec3(2047 << 21, 2047 << 10, 1023), overflowing);
384							uint force_max = overflow_factor.r | overflow_factor.g | overflow_factor.b;
385		#ifdef MOLTENVK_USED
386							atomicOr(light_only_map[lpos], force_max);
387		#else
388							imageAtomicOr(light_only_map, pos, force_max);
389		#endif
390						}
391					}
392		#endif // ALBEDO_USED
393				}
394		#endif // DENSITY_USED
395			}
396		}
397		
398		
          RDShaderFile                                    RSRC