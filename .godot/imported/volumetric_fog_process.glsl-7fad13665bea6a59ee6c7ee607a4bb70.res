RSRC                    RDShaderFile            ��������                                                  resource_local_to_scene    resource_name    bytecode_vertex    bytecode_fragment    bytecode_tesselation_control     bytecode_tesselation_evaluation    bytecode_compute    compile_error_vertex    compile_error_fragment "   compile_error_tesselation_control %   compile_error_tesselation_evaluation    compile_error_compute    script 
   _versions    base_error           local://RDShaderSPIRV_vgd3c ;         local://RDShaderFile_qqljm ��         RDShaderSPIRV          V�  Failed parse:
ERROR: 0:130: 'MAX_DIRECTIONAL_LIGHT_DATA_STRUCTS' : undeclared identifier 
ERROR: 0:130: '' : array size must be a constant integer expression
ERROR: 0:130: '' : compilation terminated 
ERROR: 3 compilation errors.  No code generated.




Stage 'compute' source code: 

1		
2		#version 450
3		
4		#
5		
6		/* Do not use subgroups here, seems there is not much advantage and causes glitches
7		#if defined(has_GL_KHR_shader_subgroup_ballot) && defined(has_GL_KHR_shader_subgroup_arithmetic)
8		#extension GL_KHR_shader_subgroup_ballot: enable
9		#extension GL_KHR_shader_subgroup_arithmetic: enable
10		
11		#define USE_SUBGROUPS
12		#endif
13		*/
14		
15		#ifdef MODE_DENSITY
16		layout(local_size_x = 4, local_size_y = 4, local_size_z = 4) in;
17		#else
18		layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
19		#endif
20		
21		
22		#define CLUSTER_COUNTER_SHIFT 20
23		#define CLUSTER_POINTER_MASK ((1 << CLUSTER_COUNTER_SHIFT) - 1)
24		#define CLUSTER_COUNTER_MASK 0xfff
25		
26		
27		#define LIGHT_BAKE_DISABLED 0
28		#define LIGHT_BAKE_STATIC 1
29		#define LIGHT_BAKE_DYNAMIC 2
30		
31		struct LightData { //this structure needs to be as packed as possible
32			highp vec3 position;
33			highp float inv_radius;
34		
35			mediump vec3 direction;
36			highp float size;
37		
38			mediump vec3 color;
39			mediump float attenuation;
40		
41			mediump float cone_attenuation;
42			mediump float cone_angle;
43			mediump float specular_amount;
44			mediump float shadow_opacity;
45		
46			highp vec4 atlas_rect; // rect in the shadow atlas
47			highp mat4 shadow_matrix;
48			highp float shadow_bias;
49			highp float shadow_normal_bias;
50			highp float transmittance_bias;
51			highp float soft_shadow_size; // for spot, it's the size in uv coordinates of the light, for omni it's the span angle
52			highp float soft_shadow_scale; // scales the shadow kernel for blurrier shadows
53			uint mask;
54			mediump float volumetric_fog_energy;
55			uint bake_mode;
56			highp vec4 projector_rect; //projector rect in srgb decal atlas
57		};
58		
59		#define REFLECTION_AMBIENT_DISABLED 0
60		#define REFLECTION_AMBIENT_ENVIRONMENT 1
61		#define REFLECTION_AMBIENT_COLOR 2
62		
63		struct ReflectionData {
64			highp vec3 box_extents;
65			mediump float index;
66			highp vec3 box_offset;
67			uint mask;
68			mediump vec3 ambient; // ambient color
69			mediump float intensity;
70			bool exterior;
71			bool box_project;
72			uint ambient_mode;
73			float exposure_normalization;
74			//0-8 is intensity,8-9 is ambient, mode
75			highp mat4 local_matrix; // up to here for spot and omni, rest is for directional
76			// notes: for ambientblend, use distance to edge to blend between already existing global environment
77		};
78		
79		struct DirectionalLightData {
80			mediump vec3 direction;
81			highp float energy; // needs to be highp to avoid NaNs being created with high energy values (i.e. when using physical light units and over-exposing the image)
82			mediump vec3 color;
83			mediump float size;
84			mediump float specular;
85			uint mask;
86			highp float softshadow_angle;
87			highp float soft_shadow_scale;
88			bool blend_splits;
89			mediump float shadow_opacity;
90			highp float fade_from;
91			highp float fade_to;
92			uvec2 pad;
93			uint bake_mode;
94			mediump float volumetric_fog_energy;
95			highp vec4 shadow_bias;
96			highp vec4 shadow_normal_bias;
97			highp vec4 shadow_transmittance_bias;
98			highp vec4 shadow_z_range;
99			highp vec4 shadow_range_begin;
100			highp vec4 shadow_split_offsets;
101			highp mat4 shadow_matrix1;
102			highp mat4 shadow_matrix2;
103			highp mat4 shadow_matrix3;
104			highp mat4 shadow_matrix4;
105			highp vec2 uv_scale1;
106			highp vec2 uv_scale2;
107			highp vec2 uv_scale3;
108			highp vec2 uv_scale4;
109		};
110		
111		
112		#define M_PI 3.14159265359
113		
114		#define DENSITY_SCALE 1024.0
115		
116		layout(set = 0, binding = 1) uniform texture2D shadow_atlas;
117		layout(set = 0, binding = 2) uniform texture2D directional_shadow_atlas;
118		
119		layout(set = 0, binding = 3, std430) restrict readonly buffer OmniLights {
120			LightData data[];
121		}
122		omni_lights;
123		
124		layout(set = 0, binding = 4, std430) restrict readonly buffer SpotLights {
125			LightData data[];
126		}
127		spot_lights;
128		
129		layout(set = 0, binding = 5, std140) uniform DirectionalLights {
130			DirectionalLightData data[MAX_DIRECTIONAL_LIGHT_DATA_STRUCTS];
131		}
132		directional_lights;
133		
134		layout(set = 0, binding = 6, std430) buffer restrict readonly ClusterBuffer {
135			uint data[];
136		}
137		cluster_buffer;
138		
139		layout(set = 0, binding = 7) uniform sampler linear_sampler;
140		
141		#ifdef MODE_DENSITY
142		layout(rgba16f, set = 0, binding = 8) uniform restrict writeonly image3D density_map;
143		#endif
144		
145		#ifdef MODE_FOG
146		layout(rgba16f, set = 0, binding = 8) uniform restrict readonly image3D density_map;
147		layout(rgba16f, set = 0, binding = 9) uniform restrict writeonly image3D fog_map;
148		#endif
149		
150		#ifdef MODE_COPY
151		layout(rgba16f, set = 0, binding = 8) uniform restrict readonly image3D source_map;
152		layout(rgba16f, set = 0, binding = 9) uniform restrict writeonly image3D dest_map;
153		#endif
154		
155		#ifdef MODE_FILTER
156		layout(rgba16f, set = 0, binding = 8) uniform restrict readonly image3D source_map;
157		layout(rgba16f, set = 0, binding = 9) uniform restrict writeonly image3D dest_map;
158		#endif
159		
160		layout(set = 0, binding = 10) uniform sampler shadow_sampler;
161		
162		#define MAX_VOXEL_GI_INSTANCES 8
163		
164		struct VoxelGIData {
165			mat4 xform; // 64 - 64
166		
167			vec3 bounds; // 12 - 76
168			float dynamic_range; // 4 - 80
169		
170			float bias; // 4 - 84
171			float normal_bias; // 4 - 88
172			bool blend_ambient; // 4 - 92
173			uint mipmaps; // 4 - 96
174		
175			vec3 pad; // 12 - 108
176			float exposure_normalization; // 4 - 112
177		};
178		
179		layout(set = 0, binding = 11, std140) uniform VoxelGIs {
180			VoxelGIData data[MAX_VOXEL_GI_INSTANCES];
181		}
182		voxel_gi_instances;
183		
184		layout(set = 0, binding = 12) uniform texture3D voxel_gi_textures[MAX_VOXEL_GI_INSTANCES];
185		
186		layout(set = 0, binding = 13) uniform sampler linear_sampler_with_mipmaps;
187		
188		#ifdef ENABLE_SDFGI
189		
190		// SDFGI Integration on set 1
191		#define SDFGI_MAX_CASCADES 8
192		
193		struct SDFVoxelGICascadeData {
194			vec3 position;
195			float to_probe;
196			ivec3 probe_world_offset;
197			float to_cell; // 1/bounds * grid_size
198			vec3 pad;
199			float exposure_normalization;
200		};
201		
202		layout(set = 1, binding = 0, std140) uniform SDFGI {
203			vec3 grid_size;
204			uint max_cascades;
205		
206			bool use_occlusion;
207			int probe_axis_size;
208			float probe_to_uvw;
209			float normal_bias;
210		
211			vec3 lightprobe_tex_pixel_size;
212			float energy;
213		
214			vec3 lightprobe_uv_offset;
215			float y_mult;
216		
217			vec3 occlusion_clamp;
218			uint pad3;
219		
220			vec3 occlusion_renormalize;
221			uint pad4;
222		
223			vec3 cascade_probe_size;
224			uint pad5;
225		
226			SDFVoxelGICascadeData cascades[SDFGI_MAX_CASCADES];
227		}
228		sdfgi;
229		
230		layout(set = 1, binding = 1) uniform texture2DArray sdfgi_ambient_texture;
231		
232		layout(set = 1, binding = 2) uniform texture3D sdfgi_occlusion_texture;
233		
234		#endif //SDFGI
235		
236		layout(set = 0, binding = 14, std140) uniform Params {
237			vec2 fog_frustum_size_begin;
238			vec2 fog_frustum_size_end;
239		
240			float fog_frustum_end;
241			float ambient_inject;
242			float z_far;
243			int filter_axis;
244		
245			vec3 ambient_color;
246			float sky_contribution;
247		
248			ivec3 fog_volume_size;
249			uint directional_light_count;
250		
251			vec3 base_emission;
252			float base_density;
253		
254			vec3 base_scattering;
255			float phase_g;
256		
257			float detail_spread;
258			float gi_inject;
259			uint max_voxel_gi_instances;
260			uint cluster_type_size;
261		
262			vec2 screen_size;
263			uint cluster_shift;
264			uint cluster_width;
265		
266			uint max_cluster_element_count_div_32;
267			bool use_temporal_reprojection;
268			uint temporal_frame;
269			float temporal_blend;
270		
271			mat3x4 cam_rotation;
272			mat4 to_prev_view;
273		
274			mat3 radiance_inverse_xform;
275		}
276		params;
277		#ifndef MODE_COPY
278		layout(set = 0, binding = 15) uniform texture3D prev_density_texture;
279		
280		#ifdef MOLTENVK_USED
281		layout(set = 0, binding = 16) buffer density_only_map_buffer {
282			uint density_only_map[];
283		};
284		layout(set = 0, binding = 17) buffer light_only_map_buffer {
285			uint light_only_map[];
286		};
287		layout(set = 0, binding = 18) buffer emissive_only_map_buffer {
288			uint emissive_only_map[];
289		};
290		#else
291		layout(r32ui, set = 0, binding = 16) uniform uimage3D density_only_map;
292		layout(r32ui, set = 0, binding = 17) uniform uimage3D light_only_map;
293		layout(r32ui, set = 0, binding = 18) uniform uimage3D emissive_only_map;
294		#endif
295		
296		#ifdef USE_RADIANCE_CUBEMAP_ARRAY
297		layout(set = 0, binding = 19) uniform textureCubeArray sky_texture;
298		#else
299		layout(set = 0, binding = 19) uniform textureCube sky_texture;
300		#endif
301		#endif // MODE_COPY
302		
303		float get_depth_at_pos(float cell_depth_size, int z) {
304			float d = float(z) * cell_depth_size + cell_depth_size * 0.5; //center of voxels
305			d = pow(d, params.detail_spread);
306			return params.fog_frustum_end * d;
307		}
308		
309		vec3 hash3f(uvec3 x) {
310			x = ((x >> 16) ^ x) * 0x45d9f3b;
311			x = ((x >> 16) ^ x) * 0x45d9f3b;
312			x = (x >> 16) ^ x;
313			return vec3(x & 0xFFFFF) / vec3(float(0xFFFFF));
314		}
315		
316		float get_omni_attenuation(float dist, float inv_range, float decay) {
317			float nd = dist * inv_range;
318			nd *= nd;
319			nd *= nd; // nd^4
320			nd = max(1.0 - nd, 0.0);
321			nd *= nd; // nd^2
322			return nd * pow(max(dist, 0.0001), -decay);
323		}
324		
325		void cluster_get_item_range(uint p_offset, out uint item_min, out uint item_max, out uint item_from, out uint item_to) {
326			uint item_min_max = cluster_buffer.data[p_offset];
327			item_min = item_min_max & 0xFFFF;
328			item_max = item_min_max >> 16;
329		
330			item_from = item_min >> 5;
331			item_to = (item_max == 0) ? 0 : ((item_max - 1) >> 5) + 1; //side effect of how it is stored, as item_max 0 means no elements
332		}
333		
334		uint cluster_get_range_clip_mask(uint i, uint z_min, uint z_max) {
335			int local_min = clamp(int(z_min) - int(i) * 32, 0, 31);
336			int mask_width = min(int(z_max) - int(z_min), 32 - local_min);
337			return bitfieldInsert(uint(0), uint(0xFFFFFFFF), local_min, mask_width);
338		}
339		
340		float henyey_greenstein(float cos_theta, float g) {
341			const float k = 0.0795774715459; // 1 / (4 * PI)
342			return k * (1.0 - g * g) / (pow(1.0 + g * g - 2.0 * g * cos_theta, 1.5));
343		}
344		
345		#define TEMPORAL_FRAMES 16
346		
347		const vec3 halton_map[TEMPORAL_FRAMES] = vec3[](
348				vec3(0.5, 0.33333333, 0.2),
349				vec3(0.25, 0.66666667, 0.4),
350				vec3(0.75, 0.11111111, 0.6),
351				vec3(0.125, 0.44444444, 0.8),
352				vec3(0.625, 0.77777778, 0.04),
353				vec3(0.375, 0.22222222, 0.24),
354				vec3(0.875, 0.55555556, 0.44),
355				vec3(0.0625, 0.88888889, 0.64),
356				vec3(0.5625, 0.03703704, 0.84),
357				vec3(0.3125, 0.37037037, 0.08),
358				vec3(0.8125, 0.7037037, 0.28),
359				vec3(0.1875, 0.14814815, 0.48),
360				vec3(0.6875, 0.48148148, 0.68),
361				vec3(0.4375, 0.81481481, 0.88),
362				vec3(0.9375, 0.25925926, 0.12),
363				vec3(0.03125, 0.59259259, 0.32));
364		
365		// Higher values will make light in volumetric fog fade out sooner when it's occluded by shadow.
366		const float INV_FOG_FADE = 10.0;
367		
368		void main() {
369			vec3 fog_cell_size = 1.0 / vec3(params.fog_volume_size);
370		
371		#ifdef MODE_DENSITY
372		
373			ivec3 pos = ivec3(gl_GlobalInvocationID.xyz);
374			if (any(greaterThanEqual(pos, params.fog_volume_size))) {
375				return; //do not compute
376			}
377		#ifdef MOLTENVK_USED
378			uint lpos = pos.z * params.fog_volume_size.x * params.fog_volume_size.y + pos.y * params.fog_volume_size.x + pos.x;
379		#endif
380		
381			vec3 posf = vec3(pos);
382		
383			//posf += mix(vec3(0.0),vec3(1.0),0.3) * hash3f(uvec3(pos)) * 2.0 - 1.0;
384		
385			vec3 fog_unit_pos = posf * fog_cell_size + fog_cell_size * 0.5; //center of voxels
386		
387			uvec2 screen_pos = uvec2(fog_unit_pos.xy * params.screen_size);
388			uvec2 cluster_pos = screen_pos >> params.cluster_shift;
389			uint cluster_offset = (params.cluster_width * cluster_pos.y + cluster_pos.x) * (params.max_cluster_element_count_div_32 + 32);
390			//positions in screen are too spread apart, no hopes for optimizing with subgroups
391		
392			fog_unit_pos.z = pow(fog_unit_pos.z, params.detail_spread);
393		
394			vec3 view_pos;
395			view_pos.xy = (fog_unit_pos.xy * 2.0 - 1.0) * mix(params.fog_frustum_size_begin, params.fog_frustum_size_end, vec2(fog_unit_pos.z));
396			view_pos.z = -params.fog_frustum_end * fog_unit_pos.z;
397			view_pos.y = -view_pos.y;
398		
399			vec4 reprojected_density = vec4(0.0);
400			float reproject_amount = 0.0;
401		
402			if (params.use_temporal_reprojection) {
403				vec3 prev_view = (params.to_prev_view * vec4(view_pos, 1.0)).xyz;
404				//undo transform into prev view
405				prev_view.y = -prev_view.y;
406				//z back to unit size
407				prev_view.z /= -params.fog_frustum_end;
408				//xy back to unit size
409				prev_view.xy /= mix(params.fog_frustum_size_begin, params.fog_frustum_size_end, vec2(prev_view.z));
410				prev_view.xy = prev_view.xy * 0.5 + 0.5;
411				//z back to unspread value
412				prev_view.z = pow(prev_view.z, 1.0 / params.detail_spread);
413		
414				if (all(greaterThan(prev_view, vec3(0.0))) && all(lessThan(prev_view, vec3(1.0)))) {
415					//reprojectinon fits
416		
417					reprojected_density = textureLod(sampler3D(prev_density_texture, linear_sampler), prev_view, 0.0);
418					reproject_amount = params.temporal_blend;
419		
420					// Since we can reproject, now we must jitter the current view pos.
421					// This is done here because cells that can't reproject should not jitter.
422		
423					fog_unit_pos = posf * fog_cell_size + fog_cell_size * halton_map[params.temporal_frame]; //center of voxels, offset by halton table
424		
425					screen_pos = uvec2(fog_unit_pos.xy * params.screen_size);
426					cluster_pos = screen_pos >> params.cluster_shift;
427					cluster_offset = (params.cluster_width * cluster_pos.y + cluster_pos.x) * (params.max_cluster_element_count_div_32 + 32);
428					//positions in screen are too spread apart, no hopes for optimizing with subgroups
429		
430					fog_unit_pos.z = pow(fog_unit_pos.z, params.detail_spread);
431		
432					view_pos.xy = (fog_unit_pos.xy * 2.0 - 1.0) * mix(params.fog_frustum_size_begin, params.fog_frustum_size_end, vec2(fog_unit_pos.z));
433					view_pos.z = -params.fog_frustum_end * fog_unit_pos.z;
434					view_pos.y = -view_pos.y;
435				}
436			}
437		
438			uint cluster_z = uint(clamp((abs(view_pos.z) / params.z_far) * 32.0, 0.0, 31.0));
439		
440			vec3 total_light = vec3(0.0);
441		
442			float total_density = params.base_density;
443		#ifdef MOLTENVK_USED
444			uint local_density = density_only_map[lpos];
445		#else
446			uint local_density = imageLoad(density_only_map, pos).x;
447		#endif
448		
449			total_density += float(int(local_density)) / DENSITY_SCALE;
450			total_density = max(0.0, total_density);
451		
452		#ifdef MOLTENVK_USED
453			uint scattering_u = light_only_map[lpos];
454		#else
455			uint scattering_u = imageLoad(light_only_map, pos).x;
456		#endif
457			vec3 scattering = vec3(scattering_u >> 21, (scattering_u << 11) >> 21, scattering_u % 1024) / vec3(2047.0, 2047.0, 1023.0);
458			scattering += params.base_scattering * params.base_density;
459		
460		#ifdef MOLTENVK_USED
461			uint emission_u = emissive_only_map[lpos];
462		#else
463			uint emission_u = imageLoad(emissive_only_map, pos).x;
464		#endif
465			vec3 emission = vec3(emission_u >> 21, (emission_u << 11) >> 21, emission_u % 1024) / vec3(511.0, 511.0, 255.0);
466			emission += params.base_emission * params.base_density;
467		
468			float cell_depth_size = abs(view_pos.z - get_depth_at_pos(fog_cell_size.z, pos.z + 1));
469			//compute directional lights
470		
471			if (total_density > 0.00005) {
472				for (uint i = 0; i < params.directional_light_count; i++) {
473					if (directional_lights.data[i].volumetric_fog_energy > 0.001) {
474						vec3 shadow_attenuation = vec3(1.0);
475		
476						if (directional_lights.data[i].shadow_opacity > 0.001) {
477							float depth_z = -view_pos.z;
478		
479							vec4 pssm_coord;
480							vec3 light_dir = directional_lights.data[i].direction;
481							vec4 v = vec4(view_pos, 1.0);
482							float z_range;
483		
484							if (depth_z < directional_lights.data[i].shadow_split_offsets.x) {
485								pssm_coord = (directional_lights.data[i].shadow_matrix1 * v);
486								pssm_coord /= pssm_coord.w;
487								z_range = directional_lights.data[i].shadow_z_range.x;
488		
489							} else if (depth_z < directional_lights.data[i].shadow_split_offsets.y) {
490								pssm_coord = (directional_lights.data[i].shadow_matrix2 * v);
491								pssm_coord /= pssm_coord.w;
492								z_range = directional_lights.data[i].shadow_z_range.y;
493		
494							} else if (depth_z < directional_lights.data[i].shadow_split_offsets.z) {
495								pssm_coord = (directional_lights.data[i].shadow_matrix3 * v);
496								pssm_coord /= pssm_coord.w;
497								z_range = directional_lights.data[i].shadow_z_range.z;
498		
499							} else {
500								pssm_coord = (directional_lights.data[i].shadow_matrix4 * v);
501								pssm_coord /= pssm_coord.w;
502								z_range = directional_lights.data[i].shadow_z_range.w;
503							}
504		
505							float depth = texture(sampler2D(directional_shadow_atlas, linear_sampler), pssm_coord.xy).r;
506							float shadow = exp(min(0.0, (depth - pssm_coord.z)) * z_range * INV_FOG_FADE);
507		
508							shadow = mix(shadow, 1.0, smoothstep(directional_lights.data[i].fade_from, directional_lights.data[i].fade_to, view_pos.z)); //done with negative values for performance
509		
510							shadow_attenuation = mix(vec3(1.0 - directional_lights.data[i].shadow_opacity), vec3(1.0), shadow);
511						}
512		
513						total_light += shadow_attenuation * directional_lights.data[i].color * directional_lights.data[i].energy * henyey_greenstein(dot(normalize(view_pos), normalize(directional_lights.data[i].direction)), params.phase_g) * directional_lights.data[i].volumetric_fog_energy;
514					}
515				}
516		
517				// Compute light from sky
518				if (params.ambient_inject > 0.0) {
519					vec3 isotropic = vec3(0.0);
520					vec3 anisotropic = vec3(0.0);
521					if (params.sky_contribution > 0.0) {
522						float mip_bias = 2.0 + total_density * (MAX_SKY_LOD - 2.0); // Not physically based, but looks nice
523						vec3 scatter_direction = (params.radiance_inverse_xform * normalize(view_pos)) * sign(params.phase_g);
524		#ifdef USE_RADIANCE_CUBEMAP_ARRAY
525						isotropic = texture(samplerCubeArray(sky_texture, linear_sampler_with_mipmaps), vec4(0.0, 1.0, 0.0, mip_bias)).rgb;
526						anisotropic = texture(samplerCubeArray(sky_texture, linear_sampler_with_mipmaps), vec4(scatter_direction, mip_bias)).rgb;
527		#else
528						isotropic = textureLod(samplerCube(sky_texture, linear_sampler_with_mipmaps), vec3(0.0, 1.0, 0.0), mip_bias).rgb;
529						anisotropic = textureLod(samplerCube(sky_texture, linear_sampler_with_mipmaps), vec3(scatter_direction), mip_bias).rgb;
530		#endif //USE_RADIANCE_CUBEMAP_ARRAY
531					}
532		
533					total_light += mix(params.ambient_color, mix(isotropic, anisotropic, abs(params.phase_g)), params.sky_contribution) * params.ambient_inject;
534				}
535		
536				//compute lights from cluster
537		
538				{ //omni lights
539		
540					uint cluster_omni_offset = cluster_offset;
541		
542					uint item_min;
543					uint item_max;
544					uint item_from;
545					uint item_to;
546		
547					cluster_get_item_range(cluster_omni_offset + params.max_cluster_element_count_div_32 + cluster_z, item_min, item_max, item_from, item_to);
548		
549		#ifdef USE_SUBGROUPS
550					item_from = subgroupBroadcastFirst(subgroupMin(item_from));
551					item_to = subgroupBroadcastFirst(subgroupMax(item_to));
552		#endif
553		
554					for (uint i = item_from; i < item_to; i++) {
555						uint mask = cluster_buffer.data[cluster_omni_offset + i];
556						mask &= cluster_get_range_clip_mask(i, item_min, item_max);
557		#ifdef USE_SUBGROUPS
558						uint merged_mask = subgroupBroadcastFirst(subgroupOr(mask));
559		#else
560						uint merged_mask = mask;
561		#endif
562		
563						while (merged_mask != 0) {
564							uint bit = findMSB(merged_mask);
565							merged_mask &= ~(1 << bit);
566		#ifdef USE_SUBGROUPS
567							if (((1 << bit) & mask) == 0) { //do not process if not originally here
568								continue;
569							}
570		#endif
571							uint light_index = 32 * i + bit;
572		
573							//if (!bool(omni_omni_lights.data[light_index].mask & draw_call.layer_mask)) {
574							//	continue; //not masked
575							//}
576		
577							vec3 light_pos = omni_lights.data[light_index].position;
578							float d = distance(omni_lights.data[light_index].position, view_pos);
579							float shadow_attenuation = 1.0;
580		
581							if (omni_lights.data[light_index].volumetric_fog_energy > 0.001 && d * omni_lights.data[light_index].inv_radius < 1.0) {
582								float attenuation = get_omni_attenuation(d, omni_lights.data[light_index].inv_radius, omni_lights.data[light_index].attenuation);
583		
584								vec3 light = omni_lights.data[light_index].color;
585		
586								if (omni_lights.data[light_index].shadow_opacity > 0.001) {
587									//has shadow
588									vec4 uv_rect = omni_lights.data[light_index].atlas_rect;
589									vec2 flip_offset = omni_lights.data[light_index].direction.xy;
590		
591									vec3 local_vert = (omni_lights.data[light_index].shadow_matrix * vec4(view_pos, 1.0)).xyz;
592		
593									float shadow_len = length(local_vert); //need to remember shadow len from here
594									vec3 shadow_sample = normalize(local_vert);
595		
596									if (shadow_sample.z >= 0.0) {
597										uv_rect.xy += flip_offset;
598									}
599		
600									shadow_sample.z = 1.0 + abs(shadow_sample.z);
601									vec3 pos = vec3(shadow_sample.xy / shadow_sample.z, shadow_len - omni_lights.data[light_index].shadow_bias);
602									pos.z *= omni_lights.data[light_index].inv_radius;
603		
604									pos.xy = pos.xy * 0.5 + 0.5;
605									pos.xy = uv_rect.xy + pos.xy * uv_rect.zw;
606		
607									float depth = texture(sampler2D(shadow_atlas, linear_sampler), pos.xy).r;
608		
609									shadow_attenuation = mix(1.0 - omni_lights.data[light_index].shadow_opacity, 1.0, exp(min(0.0, (depth - pos.z)) / omni_lights.data[light_index].inv_radius * INV_FOG_FADE));
610								}
611								total_light += light * attenuation * shadow_attenuation * henyey_greenstein(dot(normalize(light_pos - view_pos), normalize(view_pos)), params.phase_g) * omni_lights.data[light_index].volumetric_fog_energy;
612							}
613						}
614					}
615				}
616		
617				{ //spot lights
618		
619					uint cluster_spot_offset = cluster_offset + params.cluster_type_size;
620		
621					uint item_min;
622					uint item_max;
623					uint item_from;
624					uint item_to;
625		
626					cluster_get_item_range(cluster_spot_offset + params.max_cluster_element_count_div_32 + cluster_z, item_min, item_max, item_from, item_to);
627		
628		#ifdef USE_SUBGROUPS
629					item_from = subgroupBroadcastFirst(subgroupMin(item_from));
630					item_to = subgroupBroadcastFirst(subgroupMax(item_to));
631		#endif
632		
633					for (uint i = item_from; i < item_to; i++) {
634						uint mask = cluster_buffer.data[cluster_spot_offset + i];
635						mask &= cluster_get_range_clip_mask(i, item_min, item_max);
636		#ifdef USE_SUBGROUPS
637						uint merged_mask = subgroupBroadcastFirst(subgroupOr(mask));
638		#else
639						uint merged_mask = mask;
640		#endif
641		
642						while (merged_mask != 0) {
643							uint bit = findMSB(merged_mask);
644							merged_mask &= ~(1 << bit);
645		#ifdef USE_SUBGROUPS
646							if (((1 << bit) & mask) == 0) { //do not process if not originally here
647								continue;
648							}
649		#endif
650		
651							//if (!bool(omni_lights.data[light_index].mask & draw_call.layer_mask)) {
652							//	continue; //not masked
653							//}
654		
655							uint light_index = 32 * i + bit;
656		
657							vec3 light_pos = spot_lights.data[light_index].position;
658							vec3 light_rel_vec = spot_lights.data[light_index].position - view_pos;
659							float d = length(light_rel_vec);
660							float shadow_attenuation = 1.0;
661		
662							if (spot_lights.data[light_index].volumetric_fog_energy > 0.001 && d * spot_lights.data[light_index].inv_radius < 1.0) {
663								float attenuation = get_omni_attenuation(d, spot_lights.data[light_index].inv_radius, spot_lights.data[light_index].attenuation);
664		
665								vec3 spot_dir = spot_lights.data[light_index].direction;
666								highp float cone_angle = spot_lights.data[light_index].cone_angle;
667								float scos = max(dot(-normalize(light_rel_vec), spot_dir), cone_angle);
668								float spot_rim = max(0.0001, (1.0 - scos) / (1.0 - cone_angle));
669								attenuation *= 1.0 - pow(spot_rim, spot_lights.data[light_index].cone_attenuation);
670		
671								vec3 light = spot_lights.data[light_index].color;
672		
673								if (spot_lights.data[light_index].shadow_opacity > 0.001) {
674									//has shadow
675									vec4 uv_rect = spot_lights.data[light_index].atlas_rect;
676		
677									vec4 v = vec4(view_pos, 1.0);
678		
679									vec4 splane = (spot_lights.data[light_index].shadow_matrix * v);
680									splane.z -= spot_lights.data[light_index].shadow_bias / (d * spot_lights.data[light_index].inv_radius);
681									splane /= splane.w;
682		
683									vec3 pos = vec3(splane.xy * spot_lights.data[light_index].atlas_rect.zw + spot_lights.data[light_index].atlas_rect.xy, splane.z);
684		
685									float depth = texture(sampler2D(shadow_atlas, linear_sampler), pos.xy).r;
686		
687									shadow_attenuation = mix(1.0 - spot_lights.data[light_index].shadow_opacity, 1.0, exp(min(0.0, (depth - pos.z)) / spot_lights.data[light_index].inv_radius * INV_FOG_FADE));
688								}
689								total_light += light * attenuation * shadow_attenuation * henyey_greenstein(dot(normalize(light_rel_vec), normalize(view_pos)), params.phase_g) * spot_lights.data[light_index].volumetric_fog_energy;
690							}
691						}
692					}
693				}
694		
695				vec3 world_pos = mat3(params.cam_rotation) * view_pos;
696		
697				for (uint i = 0; i < params.max_voxel_gi_instances; i++) {
698					vec3 position = (voxel_gi_instances.data[i].xform * vec4(world_pos, 1.0)).xyz;
699		
700					//this causes corrupted pixels, i have no idea why..
701					if (all(bvec2(all(greaterThanEqual(position, vec3(0.0))), all(lessThan(position, voxel_gi_instances.data[i].bounds))))) {
702						position /= voxel_gi_instances.data[i].bounds;
703		
704						vec4 light = vec4(0.0);
705						for (uint j = 0; j < voxel_gi_instances.data[i].mipmaps; j++) {
706							vec4 slight = textureLod(sampler3D(voxel_gi_textures[i], linear_sampler_with_mipmaps), position, float(j));
707							float a = (1.0 - light.a);
708							light += a * slight;
709						}
710		
711						light.rgb *= voxel_gi_instances.data[i].dynamic_range * params.gi_inject * voxel_gi_instances.data[i].exposure_normalization;
712		
713						total_light += light.rgb;
714					}
715				}
716		
717				//sdfgi
718		#ifdef ENABLE_SDFGI
719		
720				{
721					float blend = -1.0;
722					vec3 ambient_total = vec3(0.0);
723		
724					for (uint i = 0; i < sdfgi.max_cascades; i++) {
725						vec3 cascade_pos = (world_pos - sdfgi.cascades[i].position) * sdfgi.cascades[i].to_probe;
726		
727						if (any(lessThan(cascade_pos, vec3(0.0))) || any(greaterThanEqual(cascade_pos, sdfgi.cascade_probe_size))) {
728							continue; //skip cascade
729						}
730		
731						vec3 base_pos = floor(cascade_pos);
732						ivec3 probe_base_pos = ivec3(base_pos);
733		
734						vec4 ambient_accum = vec4(0.0);
735		
736						ivec3 tex_pos = ivec3(probe_base_pos.xy, int(i));
737						tex_pos.x += probe_base_pos.z * sdfgi.probe_axis_size;
738		
739						for (uint j = 0; j < 8; j++) {
740							ivec3 offset = (ivec3(j) >> ivec3(0, 1, 2)) & ivec3(1, 1, 1);
741							ivec3 probe_posi = probe_base_pos;
742							probe_posi += offset;
743		
744							// Compute weight
745		
746							vec3 probe_pos = vec3(probe_posi);
747							vec3 probe_to_pos = cascade_pos - probe_pos;
748		
749							vec3 trilinear = vec3(1.0) - abs(probe_to_pos);
750							float weight = trilinear.x * trilinear.y * trilinear.z;
751		
752							// Compute lightprobe occlusion
753		
754							if (sdfgi.use_occlusion) {
755								ivec3 occ_indexv = abs((sdfgi.cascades[i].probe_world_offset + probe_posi) & ivec3(1, 1, 1)) * ivec3(1, 2, 4);
756								vec4 occ_mask = mix(vec4(0.0), vec4(1.0), equal(ivec4(occ_indexv.x | occ_indexv.y), ivec4(0, 1, 2, 3)));
757		
758								vec3 occ_pos = clamp(cascade_pos, probe_pos - sdfgi.occlusion_clamp, probe_pos + sdfgi.occlusion_clamp) * sdfgi.probe_to_uvw;
759								occ_pos.z += float(i);
760								if (occ_indexv.z != 0) { //z bit is on, means index is >=4, so make it switch to the other half of textures
761									occ_pos.x += 1.0;
762								}
763		
764								occ_pos *= sdfgi.occlusion_renormalize;
765								float occlusion = dot(textureLod(sampler3D(sdfgi_occlusion_texture, linear_sampler), occ_pos, 0.0), occ_mask);
766		
767								weight *= max(occlusion, 0.01);
768							}
769		
770							// Compute ambient texture position
771		
772							ivec3 uvw = tex_pos;
773							uvw.xy += offset.xy;
774							uvw.x += offset.z * sdfgi.probe_axis_size;
775		
776							vec3 ambient = texelFetch(sampler2DArray(sdfgi_ambient_texture, linear_sampler), uvw, 0).rgb;
777		
778							ambient_accum.rgb += ambient * weight * sdfgi.cascades[i].exposure_normalization;
779							ambient_accum.a += weight;
780						}
781		
782						if (ambient_accum.a > 0) {
783							ambient_accum.rgb /= ambient_accum.a;
784						}
785						ambient_total = ambient_accum.rgb;
786						break;
787					}
788		
789					total_light += ambient_total * params.gi_inject;
790				}
791		
792		#endif
793			}
794		
795			vec4 final_density = vec4(total_light * scattering + emission, total_density);
796		
797			final_density = mix(final_density, reprojected_density, reproject_amount);
798		
799			imageStore(density_map, pos, final_density);
800		#ifdef MOLTENVK_USED
801			density_only_map[lpos] = 0;
802			light_only_map[lpos] = 0;
803			emissive_only_map[lpos] = 0;
804		#else
805			imageStore(density_only_map, pos, uvec4(0));
806			imageStore(light_only_map, pos, uvec4(0));
807			imageStore(emissive_only_map, pos, uvec4(0));
808		#endif
809		#endif
810		
811		#ifdef MODE_FOG
812		
813			ivec3 pos = ivec3(gl_GlobalInvocationID.xy, 0);
814		
815			if (any(greaterThanEqual(pos, params.fog_volume_size))) {
816				return; //do not compute
817			}
818		
819			vec4 fog_accum = vec4(0.0, 0.0, 0.0, 1.0);
820			float prev_z = 0.0;
821		
822			for (int i = 0; i < params.fog_volume_size.z; i++) {
823				//compute fog position
824				ivec3 fog_pos = pos + ivec3(0, 0, i);
825				//get fog value
826				vec4 fog = imageLoad(density_map, fog_pos);
827		
828				//get depth at cell pos
829				float z = get_depth_at_pos(fog_cell_size.z, i);
830				//get distance from previous pos
831				float d = abs(prev_z - z);
832				//compute transmittance using beer's law
833				float transmittance = exp(-d * fog.a);
834		
835				fog_accum.rgb += ((fog.rgb - fog.rgb * transmittance) / max(fog.a, 0.00001)) * fog_accum.a;
836				fog_accum.a *= transmittance;
837		
838				prev_z = z;
839		
840				imageStore(fog_map, fog_pos, vec4(fog_accum.rgb, 1.0 - fog_accum.a));
841			}
842		
843		#endif
844		
845		#ifdef MODE_FILTER
846		
847			ivec3 pos = ivec3(gl_GlobalInvocationID.xyz);
848		
849			const float gauss[7] = float[](0.071303, 0.131514, 0.189879, 0.214607, 0.189879, 0.131514, 0.071303);
850		
851			const ivec3 filter_dir[3] = ivec3[](ivec3(1, 0, 0), ivec3(0, 1, 0), ivec3(0, 0, 1));
852			ivec3 offset = filter_dir[params.filter_axis];
853		
854			vec4 accum = vec4(0.0);
855			for (int i = -3; i <= 3; i++) {
856				accum += imageLoad(source_map, clamp(pos + offset * i, ivec3(0), params.fog_volume_size - ivec3(1))) * gauss[i + 3];
857			}
858		
859			imageStore(dest_map, pos, accum);
860		
861		#endif
862		#ifdef MODE_COPY
863			ivec3 pos = ivec3(gl_GlobalInvocationID.xyz);
864			if (any(greaterThanEqual(pos, params.fog_volume_size))) {
865				return; //do not compute
866			}
867		
868			imageStore(dest_map, pos, imageLoad(source_map, pos));
869		
870		#endif
871		}
872		
873		
          RDShaderFile                                    RSRC