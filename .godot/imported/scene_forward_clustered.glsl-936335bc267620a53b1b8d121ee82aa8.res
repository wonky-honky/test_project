RSRC                    RDShaderFile            ��������                                                  resource_local_to_scene    resource_name    bytecode_vertex    bytecode_fragment    bytecode_tesselation_control     bytecode_tesselation_evaluation    bytecode_compute    compile_error_vertex    compile_error_fragment "   compile_error_tesselation_control %   compile_error_tesselation_evaluation    compile_error_compute    script 
   _versions    base_error           local://RDShaderSPIRV_xrpdm ;         local://RDShaderFile_28wil d�        RDShaderSPIRV          �z  Failed parse:
ERROR: 0:27: '#include' : required extension not requested: GL_GOOGLE_include_directive
ERROR: 0:27: '#include' : must be followed by a header name 
ERROR: 0:27: '' : compilation terminated 
ERROR: 3 compilation errors.  No code generated.




Stage 'vertex' source code: 

1		
2		#version 450
3		
4		#
5		
6		
7		#define M_PI 3.14159265359
8		#define ROUGHNESS_MAX_LOD 5
9		
10		#define MAX_VOXEL_GI_INSTANCES 8
11		#define MAX_VIEWS 2
12		
13		#ifndef MOLTENVK_USED
14		#if defined(has_GL_KHR_shader_subgroup_ballot) && defined(has_GL_KHR_shader_subgroup_arithmetic)
15		
16		#extension GL_KHR_shader_subgroup_ballot : enable
17		#extension GL_KHR_shader_subgroup_arithmetic : enable
18		
19		#define USE_SUBGROUPS
20		#endif
21		#endif // MOLTENVK_USED
22		
23		#if defined(USE_MULTIVIEW) && defined(has_VK_KHR_multiview)
24		#extension GL_EXT_multiview : enable
25		#endif
26		
27		#include "../cluster_data_inc.glsl"
28		#include "../decal_data_inc.glsl"
29		#include "../scene_data_inc.glsl"
30		
31		#if !defined(MODE_RENDER_DEPTH) || defined(MODE_RENDER_MATERIAL) || defined(MODE_RENDER_SDF) || defined(MODE_RENDER_NORMAL_ROUGHNESS) || defined(MODE_RENDER_VOXEL_GI) || defined(TANGENT_USED) || defined(NORMAL_MAP_USED) || defined(LIGHT_ANISOTROPY_USED)
32		#ifndef NORMAL_USED
33		#define NORMAL_USED
34		#endif
35		#endif
36		
37		#if !defined(TANGENT_USED) && (defined(NORMAL_MAP_USED) || defined(LIGHT_ANISOTROPY_USED))
38		#define TANGENT_USED
39		#endif
40		
41		layout(push_constant, std430) uniform DrawCall {
42			uint instance_index;
43			uint uv_offset;
44			uint multimesh_motion_vectors_current_offset;
45			uint multimesh_motion_vectors_previous_offset;
46		}
47		draw_call;
48		
49		#define SDFGI_MAX_CASCADES 8
50		
51		/* Set 0: Base Pass (never changes) */
52		
53		#include "../light_data_inc.glsl"
54		
55		#include "../samplers_inc.glsl"
56		
57		layout(set = 0, binding = 2) uniform sampler shadow_sampler;
58		
59		layout(set = 0, binding = 3) uniform sampler decal_sampler;
60		
61		layout(set = 0, binding = 4) uniform sampler light_projector_sampler;
62		
63		#define INSTANCE_FLAGS_NON_UNIFORM_SCALE (1 << 4)
64		#define INSTANCE_FLAGS_USE_GI_BUFFERS (1 << 5)
65		#define INSTANCE_FLAGS_USE_SDFGI (1 << 6)
66		#define INSTANCE_FLAGS_USE_LIGHTMAP_CAPTURE (1 << 7)
67		#define INSTANCE_FLAGS_USE_LIGHTMAP (1 << 8)
68		#define INSTANCE_FLAGS_USE_SH_LIGHTMAP (1 << 9)
69		#define INSTANCE_FLAGS_USE_VOXEL_GI (1 << 10)
70		#define INSTANCE_FLAGS_PARTICLES (1 << 11)
71		#define INSTANCE_FLAGS_MULTIMESH (1 << 12)
72		#define INSTANCE_FLAGS_MULTIMESH_FORMAT_2D (1 << 13)
73		#define INSTANCE_FLAGS_MULTIMESH_HAS_COLOR (1 << 14)
74		#define INSTANCE_FLAGS_MULTIMESH_HAS_CUSTOM_DATA (1 << 15)
75		#define INSTANCE_FLAGS_PARTICLE_TRAIL_SHIFT 16
76		#define INSTANCE_FLAGS_FADE_SHIFT 24
77		//3 bits of stride
78		#define INSTANCE_FLAGS_PARTICLE_TRAIL_MASK 0xFF
79		
80		#define SCREEN_SPACE_EFFECTS_FLAGS_USE_SSAO 1
81		#define SCREEN_SPACE_EFFECTS_FLAGS_USE_SSIL 2
82		
83		layout(set = 0, binding = 5, std430) restrict readonly buffer OmniLights {
84			LightData data[];
85		}
86		omni_lights;
87		
88		layout(set = 0, binding = 6, std430) restrict readonly buffer SpotLights {
89			LightData data[];
90		}
91		spot_lights;
92		
93		layout(set = 0, binding = 7, std430) restrict readonly buffer ReflectionProbeData {
94			ReflectionData data[];
95		}
96		reflections;
97		
98		layout(set = 0, binding = 8, std140) uniform DirectionalLights {
99			DirectionalLightData data[MAX_DIRECTIONAL_LIGHT_DATA_STRUCTS];
100		}
101		directional_lights;
102		
103		#define LIGHTMAP_FLAG_USE_DIRECTION 1
104		#define LIGHTMAP_FLAG_USE_SPECULAR_DIRECTION 2
105		
106		struct Lightmap {
107			mat3 normal_xform;
108			vec3 pad;
109			float exposure_normalization;
110		};
111		
112		layout(set = 0, binding = 9, std140) restrict readonly buffer Lightmaps {
113			Lightmap data[];
114		}
115		lightmaps;
116		
117		struct LightmapCapture {
118			vec4 sh[9];
119		};
120		
121		layout(set = 0, binding = 10, std140) restrict readonly buffer LightmapCaptures {
122			LightmapCapture data[];
123		}
124		lightmap_captures;
125		
126		layout(set = 0, binding = 11) uniform texture2D decal_atlas;
127		layout(set = 0, binding = 12) uniform texture2D decal_atlas_srgb;
128		
129		layout(set = 0, binding = 13, std430) restrict readonly buffer Decals {
130			DecalData data[];
131		}
132		decals;
133		
134		layout(set = 0, binding = 14, std430) restrict readonly buffer GlobalShaderUniformData {
135			vec4 data[];
136		}
137		global_shader_uniforms;
138		
139		struct SDFVoxelGICascadeData {
140			vec3 position;
141			float to_probe;
142			ivec3 probe_world_offset;
143			float to_cell; // 1/bounds * grid_size
144			vec3 pad;
145			float exposure_normalization;
146		};
147		
148		layout(set = 0, binding = 15, std140) uniform SDFGI {
149			vec3 grid_size;
150			uint max_cascades;
151		
152			bool use_occlusion;
153			int probe_axis_size;
154			float probe_to_uvw;
155			float normal_bias;
156		
157			vec3 lightprobe_tex_pixel_size;
158			float energy;
159		
160			vec3 lightprobe_uv_offset;
161			float y_mult;
162		
163			vec3 occlusion_clamp;
164			uint pad3;
165		
166			vec3 occlusion_renormalize;
167			uint pad4;
168		
169			vec3 cascade_probe_size;
170			uint pad5;
171		
172			SDFVoxelGICascadeData cascades[SDFGI_MAX_CASCADES];
173		}
174		sdfgi;
175		
176		/* Set 1: Render Pass (changes per render pass) */
177		
178		layout(set = 1, binding = 0, std140) uniform SceneDataBlock {
179			SceneData data;
180			SceneData prev_data;
181		}
182		scene_data_block;
183		
184		struct ImplementationData {
185			uint cluster_shift;
186			uint cluster_width;
187			uint cluster_type_size;
188			uint max_cluster_element_count_div_32;
189		
190			uint ss_effects_flags;
191			float ssao_light_affect;
192			float ssao_ao_affect;
193			uint pad1;
194		
195			mat4 sdf_to_bounds;
196		
197			ivec3 sdf_offset;
198			uint pad2;
199		
200			ivec3 sdf_size;
201			bool gi_upscale_for_msaa;
202		
203			bool volumetric_fog_enabled;
204			float volumetric_fog_inv_length;
205			float volumetric_fog_detail_spread;
206			uint volumetric_fog_pad;
207		};
208		
209		layout(set = 1, binding = 1, std140) uniform ImplementationDataBlock {
210			ImplementationData data;
211		}
212		implementation_data_block;
213		
214		#define implementation_data implementation_data_block.data
215		
216		struct InstanceData {
217			mat4 transform;
218			mat4 prev_transform;
219			uint flags;
220			uint instance_uniforms_ofs; //base offset in global buffer for instance variables
221			uint gi_offset; //GI information when using lightmapping (VCT or lightmap index)
222			uint layer_mask;
223			vec4 lightmap_uv_scale;
224			vec4 compressed_aabb_position_pad; // Only .xyz is used. .w is padding.
225			vec4 compressed_aabb_size_pad; // Only .xyz is used. .w is padding.
226			vec4 uv_scale;
227		};
228		
229		layout(set = 1, binding = 2, std430) buffer restrict readonly InstanceDataBuffer {
230			InstanceData data[];
231		}
232		instances;
233		
234		#ifdef USE_RADIANCE_CUBEMAP_ARRAY
235		
236		layout(set = 1, binding = 3) uniform textureCubeArray radiance_cubemap;
237		
238		#else
239		
240		layout(set = 1, binding = 3) uniform textureCube radiance_cubemap;
241		
242		#endif
243		
244		layout(set = 1, binding = 4) uniform textureCubeArray reflection_atlas;
245		
246		layout(set = 1, binding = 5) uniform texture2D shadow_atlas;
247		
248		layout(set = 1, binding = 6) uniform texture2D directional_shadow_atlas;
249		
250		layout(set = 1, binding = 7) uniform texture2DArray lightmap_textures[MAX_LIGHTMAP_TEXTURES];
251		
252		layout(set = 1, binding = 8) uniform texture3D voxel_gi_textures[MAX_VOXEL_GI_INSTANCES];
253		
254		layout(set = 1, binding = 9, std430) buffer restrict readonly ClusterBuffer {
255			uint data[];
256		}
257		cluster_buffer;
258		
259		#ifdef MODE_RENDER_SDF
260		
261		layout(r16ui, set = 1, binding = 10) uniform restrict writeonly uimage3D albedo_volume_grid;
262		layout(r32ui, set = 1, binding = 11) uniform restrict writeonly uimage3D emission_grid;
263		layout(r32ui, set = 1, binding = 12) uniform restrict writeonly uimage3D emission_aniso_grid;
264		layout(r32ui, set = 1, binding = 13) uniform restrict uimage3D geom_facing_grid;
265		
266		//still need to be present for shaders that use it, so remap them to something
267		#define depth_buffer shadow_atlas
268		#define color_buffer shadow_atlas
269		#define normal_roughness_buffer shadow_atlas
270		
271		#define multiviewSampler sampler2D
272		#else
273		
274		#ifdef USE_MULTIVIEW
275		layout(set = 1, binding = 10) uniform texture2DArray depth_buffer;
276		layout(set = 1, binding = 11) uniform texture2DArray color_buffer;
277		layout(set = 1, binding = 12) uniform texture2DArray normal_roughness_buffer;
278		layout(set = 1, binding = 13) uniform texture2DArray ao_buffer;
279		layout(set = 1, binding = 14) uniform texture2DArray ambient_buffer;
280		layout(set = 1, binding = 15) uniform texture2DArray reflection_buffer;
281		#define multiviewSampler sampler2DArray
282		#else // USE_MULTIVIEW
283		layout(set = 1, binding = 10) uniform texture2D depth_buffer;
284		layout(set = 1, binding = 11) uniform texture2D color_buffer;
285		layout(set = 1, binding = 12) uniform texture2D normal_roughness_buffer;
286		layout(set = 1, binding = 13) uniform texture2D ao_buffer;
287		layout(set = 1, binding = 14) uniform texture2D ambient_buffer;
288		layout(set = 1, binding = 15) uniform texture2D reflection_buffer;
289		#define multiviewSampler sampler2D
290		#endif
291		layout(set = 1, binding = 16) uniform texture2DArray sdfgi_lightprobe_texture;
292		layout(set = 1, binding = 17) uniform texture3D sdfgi_occlusion_cascades;
293		
294		struct VoxelGIData {
295			mat4 xform; // 64 - 64
296		
297			vec3 bounds; // 12 - 76
298			float dynamic_range; // 4 - 80
299		
300			float bias; // 4 - 84
301			float normal_bias; // 4 - 88
302			bool blend_ambient; // 4 - 92
303			uint mipmaps; // 4 - 96
304		
305			vec3 pad; // 12 - 108
306			float exposure_normalization; // 4 - 112
307		};
308		
309		layout(set = 1, binding = 18, std140) uniform VoxelGIs {
310			VoxelGIData data[MAX_VOXEL_GI_INSTANCES];
311		}
312		voxel_gi_instances;
313		
314		layout(set = 1, binding = 19) uniform texture3D volumetric_fog_texture;
315		
316		#ifdef USE_MULTIVIEW
317		layout(set = 1, binding = 20) uniform texture2DArray ssil_buffer;
318		#else
319		layout(set = 1, binding = 20) uniform texture2D ssil_buffer;
320		#endif // USE_MULTIVIEW
321		
322		#endif
323		
324		/* Set 2 Skeleton & Instancing (can change per item) */
325		
326		layout(set = 2, binding = 0, std430) restrict readonly buffer Transforms {
327			vec4 data[];
328		}
329		transforms;
330		
331		/* Set 3 User Material */
332		
333		
334		#define SHADER_IS_SRGB false
335		
336		/* INPUT ATTRIBS */
337		
338		// Always contains vertex position in XYZ, can contain tangent angle in W.
339		layout(location = 0) in vec4 vertex_angle_attrib;
340		
341		//only for pure render depth when normal is not used
342		
343		#if defined(NORMAL_USED) || defined(TANGENT_USED)
344		// Contains Normal/Axis in RG, can contain tangent in BA.
345		layout(location = 1) in vec4 axis_tangent_attrib;
346		#endif
347		
348		// Location 2 is unused.
349		
350		#if defined(COLOR_USED)
351		layout(location = 3) in vec4 color_attrib;
352		#endif
353		
354		#ifdef UV_USED
355		layout(location = 4) in vec2 uv_attrib;
356		#endif
357		
358		#if defined(UV2_USED) || defined(USE_LIGHTMAP) || defined(MODE_RENDER_MATERIAL)
359		layout(location = 5) in vec2 uv2_attrib;
360		#endif
361		
362		#if defined(CUSTOM0_USED)
363		layout(location = 6) in vec4 custom0_attrib;
364		#endif
365		
366		#if defined(CUSTOM1_USED)
367		layout(location = 7) in vec4 custom1_attrib;
368		#endif
369		
370		#if defined(CUSTOM2_USED)
371		layout(location = 8) in vec4 custom2_attrib;
372		#endif
373		
374		#if defined(CUSTOM3_USED)
375		layout(location = 9) in vec4 custom3_attrib;
376		#endif
377		
378		#if defined(BONES_USED) || defined(USE_PARTICLE_TRAILS)
379		layout(location = 10) in uvec4 bone_attrib;
380		#endif
381		
382		#if defined(WEIGHTS_USED) || defined(USE_PARTICLE_TRAILS)
383		layout(location = 11) in vec4 weight_attrib;
384		#endif
385		
386		#ifdef MOTION_VECTORS
387		layout(location = 12) in vec4 previous_vertex_attrib;
388		
389		#if defined(NORMAL_USED) || defined(TANGENT_USED)
390		layout(location = 13) in vec4 previous_normal_attrib;
391		#endif
392		
393		#endif // MOTION_VECTORS
394		
395		vec3 oct_to_vec3(vec2 e) {
396			vec3 v = vec3(e.xy, 1.0 - abs(e.x) - abs(e.y));
397			float t = max(-v.z, 0.0);
398			v.xy += t * -sign(v.xy);
399			return normalize(v);
400		}
401		
402		void axis_angle_to_tbn(vec3 axis, float angle, out vec3 tangent, out vec3 binormal, out vec3 normal) {
403			float c = cos(angle);
404			float s = sin(angle);
405			vec3 omc_axis = (1.0 - c) * axis;
406			vec3 s_axis = s * axis;
407			tangent = omc_axis.xxx * axis + vec3(c, -s_axis.z, s_axis.y);
408			binormal = omc_axis.yyy * axis + vec3(s_axis.z, c, -s_axis.x);
409			normal = omc_axis.zzz * axis + vec3(-s_axis.y, s_axis.x, c);
410		}
411		
412		/* Varyings */
413		
414		layout(location = 0) out vec3 vertex_interp;
415		
416		#ifdef NORMAL_USED
417		layout(location = 1) out vec3 normal_interp;
418		#endif
419		
420		#if defined(COLOR_USED)
421		layout(location = 2) out vec4 color_interp;
422		#endif
423		
424		#ifdef UV_USED
425		layout(location = 3) out vec2 uv_interp;
426		#endif
427		
428		#if defined(UV2_USED) || defined(USE_LIGHTMAP)
429		layout(location = 4) out vec2 uv2_interp;
430		#endif
431		
432		#ifdef TANGENT_USED
433		layout(location = 5) out vec3 tangent_interp;
434		layout(location = 6) out vec3 binormal_interp;
435		#endif
436		
437		#ifdef MOTION_VECTORS
438		layout(location = 7) out vec4 screen_position;
439		layout(location = 8) out vec4 prev_screen_position;
440		#endif
441		
442		#ifdef MATERIAL_UNIFORMS_USED
443		layout(set = MATERIAL_UNIFORM_SET, binding = 0, std140) uniform MaterialUniforms{
444		#MATERIAL_UNIFORMS
445		} material;
446		#endif
447		
448		float global_time;
449		
450		#ifdef MODE_DUAL_PARABOLOID
451		
452		layout(location = 9) out float dp_clip;
453		
454		#endif
455		
456		layout(location = 10) out flat uint instance_index_interp;
457		
458		#ifdef USE_MULTIVIEW
459		#ifdef has_VK_KHR_multiview
460		#define ViewIndex gl_ViewIndex
461		#else // has_VK_KHR_multiview
462		// !BAS! This needs to become an input once we implement our fallback!
463		#define ViewIndex 0
464		#endif // has_VK_KHR_multiview
465		vec3 multiview_uv(vec2 uv) {
466			return vec3(uv, ViewIndex);
467		}
468		layout(location = 11) out vec4 combined_projected;
469		#else // USE_MULTIVIEW
470		// Set to zero, not supported in non stereo
471		#define ViewIndex 0
472		vec2 multiview_uv(vec2 uv) {
473			return uv;
474		}
475		#endif //USE_MULTIVIEW
476		
477		invariant gl_Position;
478		
479		#GLOBALS
480		
481		#ifdef USE_DOUBLE_PRECISION
482		// Helper functions for emulating double precision when adding floats.
483		vec3 quick_two_sum(vec3 a, vec3 b, out vec3 out_p) {
484			vec3 s = a + b;
485			out_p = b - (s - a);
486			return s;
487		}
488		
489		vec3 two_sum(vec3 a, vec3 b, out vec3 out_p) {
490			vec3 s = a + b;
491			vec3 v = s - a;
492			out_p = (a - (s - v)) + (b - v);
493			return s;
494		}
495		
496		vec3 double_add_vec3(vec3 base_a, vec3 prec_a, vec3 base_b, vec3 prec_b, out vec3 out_precision) {
497			vec3 s, t, se, te;
498			s = two_sum(base_a, base_b, se);
499			t = two_sum(prec_a, prec_b, te);
500			se += t;
501			s = quick_two_sum(s, se, se);
502			se += te;
503			s = quick_two_sum(s, se, out_precision);
504			return s;
505		}
506		#endif
507		
508		void vertex_shader(vec3 vertex_input,
509		#ifdef NORMAL_USED
510				in vec3 normal_input,
511		#endif
512		#ifdef TANGENT_USED
513				in vec3 tangent_input,
514				in vec3 binormal_input,
515		#endif
516				in uint instance_index, in bool is_multimesh, in uint multimesh_offset, in SceneData scene_data, in mat4 model_matrix, out vec4 screen_pos) {
517			vec4 instance_custom = vec4(0.0);
518		#if defined(COLOR_USED)
519			color_interp = color_attrib;
520		#endif
521		
522			mat4 inv_view_matrix = scene_data.inv_view_matrix;
523		
524		#ifdef USE_DOUBLE_PRECISION
525			vec3 model_precision = vec3(model_matrix[0][3], model_matrix[1][3], model_matrix[2][3]);
526			model_matrix[0][3] = 0.0;
527			model_matrix[1][3] = 0.0;
528			model_matrix[2][3] = 0.0;
529			vec3 view_precision = vec3(inv_view_matrix[0][3], inv_view_matrix[1][3], inv_view_matrix[2][3]);
530			inv_view_matrix[0][3] = 0.0;
531			inv_view_matrix[1][3] = 0.0;
532			inv_view_matrix[2][3] = 0.0;
533		#endif
534		
535			mat3 model_normal_matrix;
536			if (bool(instances.data[instance_index].flags & INSTANCE_FLAGS_NON_UNIFORM_SCALE)) {
537				model_normal_matrix = transpose(inverse(mat3(model_matrix)));
538			} else {
539				model_normal_matrix = mat3(model_matrix);
540			}
541		
542			mat4 matrix;
543			mat4 read_model_matrix = model_matrix;
544		
545			if (is_multimesh) {
546				//multimesh, instances are for it
547		
548		#ifdef USE_PARTICLE_TRAILS
549				uint trail_size = (instances.data[instance_index].flags >> INSTANCE_FLAGS_PARTICLE_TRAIL_SHIFT) & INSTANCE_FLAGS_PARTICLE_TRAIL_MASK;
550				uint stride = 3 + 1 + 1; //particles always uses this format
551		
552				uint offset = trail_size * stride * gl_InstanceIndex;
553		
554		#ifdef COLOR_USED
555				vec4 pcolor;
556		#endif
557				{
558					uint boffset = offset + bone_attrib.x * stride;
559					matrix = mat4(transforms.data[boffset + 0], transforms.data[boffset + 1], transforms.data[boffset + 2], vec4(0.0, 0.0, 0.0, 1.0)) * weight_attrib.x;
560		#ifdef COLOR_USED
561					pcolor = transforms.data[boffset + 3] * weight_attrib.x;
562		#endif
563				}
564				if (weight_attrib.y > 0.001) {
565					uint boffset = offset + bone_attrib.y * stride;
566					matrix += mat4(transforms.data[boffset + 0], transforms.data[boffset + 1], transforms.data[boffset + 2], vec4(0.0, 0.0, 0.0, 1.0)) * weight_attrib.y;
567		#ifdef COLOR_USED
568					pcolor += transforms.data[boffset + 3] * weight_attrib.y;
569		#endif
570				}
571				if (weight_attrib.z > 0.001) {
572					uint boffset = offset + bone_attrib.z * stride;
573					matrix += mat4(transforms.data[boffset + 0], transforms.data[boffset + 1], transforms.data[boffset + 2], vec4(0.0, 0.0, 0.0, 1.0)) * weight_attrib.z;
574		#ifdef COLOR_USED
575					pcolor += transforms.data[boffset + 3] * weight_attrib.z;
576		#endif
577				}
578				if (weight_attrib.w > 0.001) {
579					uint boffset = offset + bone_attrib.w * stride;
580					matrix += mat4(transforms.data[boffset + 0], transforms.data[boffset + 1], transforms.data[boffset + 2], vec4(0.0, 0.0, 0.0, 1.0)) * weight_attrib.w;
581		#ifdef COLOR_USED
582					pcolor += transforms.data[boffset + 3] * weight_attrib.w;
583		#endif
584				}
585		
586				instance_custom = transforms.data[offset + 4];
587		
588		#ifdef COLOR_USED
589				color_interp *= pcolor;
590		#endif
591		
592		#else
593				uint stride = 0;
594				{
595					//TODO implement a small lookup table for the stride
596					if (bool(instances.data[instance_index].flags & INSTANCE_FLAGS_MULTIMESH_FORMAT_2D)) {
597						stride += 2;
598					} else {
599						stride += 3;
600					}
601					if (bool(instances.data[instance_index].flags & INSTANCE_FLAGS_MULTIMESH_HAS_COLOR)) {
602						stride += 1;
603					}
604					if (bool(instances.data[instance_index].flags & INSTANCE_FLAGS_MULTIMESH_HAS_CUSTOM_DATA)) {
605						stride += 1;
606					}
607				}
608		
609				uint offset = stride * (gl_InstanceIndex + multimesh_offset);
610		
611				if (bool(instances.data[instance_index].flags & INSTANCE_FLAGS_MULTIMESH_FORMAT_2D)) {
612					matrix = mat4(transforms.data[offset + 0], transforms.data[offset + 1], vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
613					offset += 2;
614				} else {
615					matrix = mat4(transforms.data[offset + 0], transforms.data[offset + 1], transforms.data[offset + 2], vec4(0.0, 0.0, 0.0, 1.0));
616					offset += 3;
617				}
618		
619				if (bool(instances.data[instance_index].flags & INSTANCE_FLAGS_MULTIMESH_HAS_COLOR)) {
620		#ifdef COLOR_USED
621					color_interp *= transforms.data[offset];
622		#endif
623					offset += 1;
624				}
625		
626				if (bool(instances.data[instance_index].flags & INSTANCE_FLAGS_MULTIMESH_HAS_CUSTOM_DATA)) {
627					instance_custom = transforms.data[offset];
628				}
629		
630		#endif
631				//transpose
632				matrix = transpose(matrix);
633		#if !defined(USE_DOUBLE_PRECISION) || defined(SKIP_TRANSFORM_USED) || defined(VERTEX_WORLD_COORDS_USED) || defined(MODEL_MATRIX_USED)
634				// Normally we can bake the multimesh transform into the model matrix, but when using double precision
635				// we avoid baking it in so we can emulate high precision.
636				read_model_matrix = model_matrix * matrix;
637		#if !defined(USE_DOUBLE_PRECISION) || defined(SKIP_TRANSFORM_USED) || defined(VERTEX_WORLD_COORDS_USED)
638				model_matrix = read_model_matrix;
639		#endif // !defined(USE_DOUBLE_PRECISION) || defined(SKIP_TRANSFORM_USED) || defined(VERTEX_WORLD_COORDS_USED)
640		#endif // !defined(USE_DOUBLE_PRECISION) || defined(SKIP_TRANSFORM_USED) || defined(VERTEX_WORLD_COORDS_USED) || defined(MODEL_MATRIX_USED)
641				model_normal_matrix = model_normal_matrix * mat3(matrix);
642			}
643		
644			vec3 vertex = vertex_input;
645		#ifdef NORMAL_USED
646			vec3 normal = normal_input;
647		#endif
648		
649		#ifdef TANGENT_USED
650			vec3 tangent = tangent_input;
651			vec3 binormal = binormal_input;
652		#endif
653		
654		#ifdef UV_USED
655			uv_interp = uv_attrib;
656		#endif
657		
658		#if defined(UV2_USED) || defined(USE_LIGHTMAP)
659			uv2_interp = uv2_attrib;
660		#endif
661		
662			vec4 uv_scale = instances.data[instance_index].uv_scale;
663		
664			if (uv_scale != vec4(0.0)) { // Compression enabled
665		#ifdef UV_USED
666				uv_interp = (uv_interp - 0.5) * uv_scale.xy;
667		#endif
668		#if defined(UV2_USED) || defined(USE_LIGHTMAP)
669				uv2_interp = (uv2_interp - 0.5) * uv_scale.zw;
670		#endif
671			}
672		
673		#ifdef OVERRIDE_POSITION
674			vec4 position;
675		#endif
676		
677		#ifdef USE_MULTIVIEW
678			mat4 combined_projection = scene_data.projection_matrix;
679			mat4 projection_matrix = scene_data.projection_matrix_view[ViewIndex];
680			mat4 inv_projection_matrix = scene_data.inv_projection_matrix_view[ViewIndex];
681			vec3 eye_offset = scene_data.eye_offset[ViewIndex].xyz;
682		#else
683			mat4 projection_matrix = scene_data.projection_matrix;
684			mat4 inv_projection_matrix = scene_data.inv_projection_matrix;
685			vec3 eye_offset = vec3(0.0, 0.0, 0.0);
686		#endif //USE_MULTIVIEW
687		
688		//using world coordinates
689		#if !defined(SKIP_TRANSFORM_USED) && defined(VERTEX_WORLD_COORDS_USED)
690		
691			vertex = (model_matrix * vec4(vertex, 1.0)).xyz;
692		
693		#ifdef NORMAL_USED
694			normal = model_normal_matrix * normal;
695		#endif
696		
697		#ifdef TANGENT_USED
698		
699			tangent = model_normal_matrix * tangent;
700			binormal = model_normal_matrix * binormal;
701		
702		#endif
703		#endif
704		
705			float roughness = 1.0;
706		
707			mat4 modelview = scene_data.view_matrix * model_matrix;
708			mat3 modelview_normal = mat3(scene_data.view_matrix) * model_normal_matrix;
709			mat4 read_view_matrix = scene_data.view_matrix;
710			vec2 read_viewport_size = scene_data.viewport_size;
711		
712			{
713		#CODE : VERTEX
714			}
715		
716		// using local coordinates (default)
717		#if !defined(SKIP_TRANSFORM_USED) && !defined(VERTEX_WORLD_COORDS_USED)
718		
719		#ifdef USE_DOUBLE_PRECISION
720			// We separate the basis from the origin because the basis is fine with single point precision.
721			// Then we combine the translations from the model matrix and the view matrix using emulated doubles.
722			// We add the result to the vertex and ignore the final lost precision.
723			vec3 model_origin = model_matrix[3].xyz;
724			if (is_multimesh) {
725				vertex = mat3(matrix) * vertex;
726				model_origin = double_add_vec3(model_origin, model_precision, matrix[3].xyz, vec3(0.0), model_precision);
727			}
728			vertex = mat3(inv_view_matrix * modelview) * vertex;
729			vec3 temp_precision; // Will be ignored.
730			vertex += double_add_vec3(model_origin, model_precision, scene_data.inv_view_matrix[3].xyz, view_precision, temp_precision);
731			vertex = mat3(scene_data.view_matrix) * vertex;
732		#else
733			vertex = (modelview * vec4(vertex, 1.0)).xyz;
734		#endif
735		#ifdef NORMAL_USED
736			normal = modelview_normal * normal;
737		#endif
738		
739		#ifdef TANGENT_USED
740		
741			binormal = modelview_normal * binormal;
742			tangent = modelview_normal * tangent;
743		#endif
744		#endif // !defined(SKIP_TRANSFORM_USED) && !defined(VERTEX_WORLD_COORDS_USED)
745		
746		//using world coordinates
747		#if !defined(SKIP_TRANSFORM_USED) && defined(VERTEX_WORLD_COORDS_USED)
748		
749			vertex = (scene_data.view_matrix * vec4(vertex, 1.0)).xyz;
750		#ifdef NORMAL_USED
751			normal = (scene_data.view_matrix * vec4(normal, 0.0)).xyz;
752		#endif
753		
754		#ifdef TANGENT_USED
755			binormal = (scene_data.view_matrix * vec4(binormal, 0.0)).xyz;
756			tangent = (scene_data.view_matrix * vec4(tangent, 0.0)).xyz;
757		#endif
758		#endif
759		
760			vertex_interp = vertex;
761		
762		#ifdef NORMAL_USED
763			normal_interp = normal;
764		#endif
765		
766		#ifdef TANGENT_USED
767			tangent_interp = tangent;
768			binormal_interp = binormal;
769		#endif
770		
771		#ifdef MODE_RENDER_DEPTH
772		
773		#ifdef MODE_DUAL_PARABOLOID
774		
775			vertex_interp.z *= scene_data.dual_paraboloid_side;
776		
777			dp_clip = vertex_interp.z; //this attempts to avoid noise caused by objects sent to the other parabolloid side due to bias
778		
779			//for dual paraboloid shadow mapping, this is the fastest but least correct way, as it curves straight edges
780		
781			vec3 vtx = vertex_interp;
782			float distance = length(vtx);
783			vtx = normalize(vtx);
784			vtx.xy /= 1.0 - vtx.z;
785			vtx.z = (distance / scene_data.z_far);
786			vtx.z = vtx.z * 2.0 - 1.0;
787			vertex_interp = vtx;
788		
789		#endif
790		
791		#endif //MODE_RENDER_DEPTH
792		
793		#ifdef OVERRIDE_POSITION
794			gl_Position = position;
795		#else
796			gl_Position = projection_matrix * vec4(vertex_interp, 1.0);
797		#endif
798		
799		#ifdef USE_MULTIVIEW
800			combined_projected = combined_projection * vec4(vertex_interp, 1.0);
801		#endif
802		
803		#ifdef MOTION_VECTORS
804			screen_pos = gl_Position;
805		#endif
806		
807		#ifdef MODE_RENDER_DEPTH
808			if (scene_data.pancake_shadows) {
809				if (gl_Position.z <= 0.00001) {
810					gl_Position.z = 0.00001;
811				}
812			}
813		#endif
814		#ifdef MODE_RENDER_MATERIAL
815			if (scene_data.material_uv2_mode) {
816				vec2 uv_offset = unpackHalf2x16(draw_call.uv_offset);
817				gl_Position.xy = (uv2_attrib.xy + uv_offset) * 2.0 - 1.0;
818				gl_Position.z = 0.00001;
819				gl_Position.w = 1.0;
820			}
821		#endif
822		}
823		
824		void _unpack_vertex_attributes(vec4 p_vertex_in, vec3 p_compressed_aabb_position, vec3 p_compressed_aabb_size,
825		#if defined(NORMAL_USED) || defined(TANGENT_USED)
826				vec4 p_normal_in,
827		#ifdef NORMAL_USED
828				out vec3 r_normal,
829		#endif
830				out vec3 r_tangent,
831				out vec3 r_binormal,
832		#endif
833				out vec3 r_vertex) {
834		
835			r_vertex = p_vertex_in.xyz * p_compressed_aabb_size + p_compressed_aabb_position;
836		#ifdef NORMAL_USED
837			r_normal = oct_to_vec3(p_normal_in.xy * 2.0 - 1.0);
838		#endif
839		
840		#if defined(NORMAL_USED) || defined(TANGENT_USED)
841		
842			float binormal_sign;
843		
844			// This works because the oct value (0, 1) maps onto (0, 0, -1) which encodes to (1, 1).
845			// Accordingly, if p_normal_in.z contains octahedral values, it won't equal (0, 1).
846			if (p_normal_in.z > 0.0 || p_normal_in.w < 1.0) {
847				// Uncompressed format.
848				vec2 signed_tangent_attrib = p_normal_in.zw * 2.0 - 1.0;
849				r_tangent = oct_to_vec3(vec2(signed_tangent_attrib.x, abs(signed_tangent_attrib.y) * 2.0 - 1.0));
850				binormal_sign = sign(signed_tangent_attrib.y);
851				r_binormal = normalize(cross(r_normal, r_tangent) * binormal_sign);
852			} else {
853				// Compressed format.
854				float angle = p_vertex_in.w;
855				binormal_sign = angle > 0.5 ? 1.0 : -1.0; // 0.5 does not exist in UNORM16, so values are either greater or smaller.
856				angle = abs(angle * 2.0 - 1.0) * M_PI; // 0.5 is basically zero, allowing to encode both signs reliably.
857				vec3 axis = r_normal;
858				axis_angle_to_tbn(axis, angle, r_tangent, r_binormal, r_normal);
859				r_binormal *= binormal_sign;
860			}
861		#endif
862		}
863		
864		void main() {
865			uint instance_index = draw_call.instance_index;
866		
867			bool is_multimesh = bool(instances.data[instance_index].flags & INSTANCE_FLAGS_MULTIMESH);
868			if (!is_multimesh) {
869				instance_index += gl_InstanceIndex;
870			}
871		
872			instance_index_interp = instance_index;
873		
874			mat4 model_matrix = instances.data[instance_index].transform;
875		
876		#ifdef MOTION_VECTORS
877			// Previous vertex.
878			vec3 prev_vertex;
879		#ifdef NORMAL_USED
880			vec3 prev_normal;
881		#endif
882		#if defined(NORMAL_USED) || defined(TANGENT_USED)
883			vec3 prev_tangent;
884			vec3 prev_binormal;
885		#endif
886		
887			_unpack_vertex_attributes(
888					previous_vertex_attrib,
889					instances.data[instance_index].compressed_aabb_position_pad.xyz,
890					instances.data[instance_index].compressed_aabb_size_pad.xyz,
891		
892		#if defined(NORMAL_USED) || defined(TANGENT_USED)
893					previous_normal_attrib,
894		#ifdef NORMAL_USED
895					prev_normal,
896		#endif
897					prev_tangent,
898					prev_binormal,
899		#endif
900					prev_vertex);
901		
902			global_time = scene_data_block.prev_data.time;
903			vertex_shader(prev_vertex,
904		#ifdef NORMAL_USED
905					prev_normal,
906		#endif
907		#ifdef TANGENT_USED
908					prev_tangent,
909					prev_binormal,
910		#endif
911					instance_index, is_multimesh, draw_call.multimesh_motion_vectors_previous_offset, scene_data_block.prev_data, instances.data[instance_index].prev_transform, prev_screen_position);
912		#else
913			// Unused output.
914			vec4 screen_position;
915		#endif
916		
917			vec3 vertex;
918		#ifdef NORMAL_USED
919			vec3 normal;
920		#endif
921		#if defined(NORMAL_USED) || defined(TANGENT_USED)
922			vec3 tangent;
923			vec3 binormal;
924		#endif
925		
926			_unpack_vertex_attributes(
927					vertex_angle_attrib,
928					instances.data[instance_index].compressed_aabb_position_pad.xyz,
929					instances.data[instance_index].compressed_aabb_size_pad.xyz,
930		#if defined(NORMAL_USED) || defined(TANGENT_USED)
931					axis_tangent_attrib,
932		#ifdef NORMAL_USED
933					normal,
934		#endif
935					tangent,
936					binormal,
937		#endif
938					vertex);
939		
940			// Current vertex.
941			global_time = scene_data_block.data.time;
942			vertex_shader(vertex,
943		#ifdef NORMAL_USED
944					normal,
945		#endif
946		#ifdef TANGENT_USED
947					tangent,
948					binormal,
949		#endif
950					instance_index, is_multimesh, draw_call.multimesh_motion_vectors_current_offset, scene_data_block.data, model_matrix, screen_position);
951		}
952		
953		
       j Failed parse:
ERROR: 0:50: '#include' : required extension not requested: GL_GOOGLE_include_directive
ERROR: 0:50: '#include' : must be followed by a header name 
ERROR: 2 compilation errors.  No code generated.




Stage 'fragment' source code: 

1		
2		#version 450
3		
4		#
5		
6		#define SHADER_IS_SRGB false
7		
8		/* Specialization Constants (Toggles) */
9		
10		layout(constant_id = 0) const bool sc_use_forward_gi = false;
11		layout(constant_id = 1) const bool sc_use_light_projector = false;
12		layout(constant_id = 2) const bool sc_use_light_soft_shadows = false;
13		layout(constant_id = 3) const bool sc_use_directional_soft_shadows = false;
14		
15		/* Specialization Constants (Values) */
16		
17		layout(constant_id = 6) const uint sc_soft_shadow_samples = 4;
18		layout(constant_id = 7) const uint sc_penumbra_shadow_samples = 4;
19		
20		layout(constant_id = 8) const uint sc_directional_soft_shadow_samples = 4;
21		layout(constant_id = 9) const uint sc_directional_penumbra_shadow_samples = 4;
22		
23		layout(constant_id = 10) const bool sc_decal_use_mipmaps = true;
24		layout(constant_id = 11) const bool sc_projector_use_mipmaps = true;
25		
26		// not used in clustered renderer but we share some code with the mobile renderer that requires this.
27		const float sc_luminance_multiplier = 1.0;
28		
29		
30		#define M_PI 3.14159265359
31		#define ROUGHNESS_MAX_LOD 5
32		
33		#define MAX_VOXEL_GI_INSTANCES 8
34		#define MAX_VIEWS 2
35		
36		#ifndef MOLTENVK_USED
37		#if defined(has_GL_KHR_shader_subgroup_ballot) && defined(has_GL_KHR_shader_subgroup_arithmetic)
38		
39		#extension GL_KHR_shader_subgroup_ballot : enable
40		#extension GL_KHR_shader_subgroup_arithmetic : enable
41		
42		#define USE_SUBGROUPS
43		#endif
44		#endif // MOLTENVK_USED
45		
46		#if defined(USE_MULTIVIEW) && defined(has_VK_KHR_multiview)
47		#extension GL_EXT_multiview : enable
48		#endif
49		
50		#include "../cluster_data_inc.glsl"
51		#include "../decal_data_inc.glsl"
52		#include "../scene_data_inc.glsl"
53		
54		#if !defined(MODE_RENDER_DEPTH) || defined(MODE_RENDER_MATERIAL) || defined(MODE_RENDER_SDF) || defined(MODE_RENDER_NORMAL_ROUGHNESS) || defined(MODE_RENDER_VOXEL_GI) || defined(TANGENT_USED) || defined(NORMAL_MAP_USED) || defined(LIGHT_ANISOTROPY_USED)
55		#ifndef NORMAL_USED
56		#define NORMAL_USED
57		#endif
58		#endif
59		
60		#if !defined(TANGENT_USED) && (defined(NORMAL_MAP_USED) || defined(LIGHT_ANISOTROPY_USED))
61		#define TANGENT_USED
62		#endif
63		
64		layout(push_constant, std430) uniform DrawCall {
65			uint instance_index;
66			uint uv_offset;
67			uint multimesh_motion_vectors_current_offset;
68			uint multimesh_motion_vectors_previous_offset;
69		}
70		draw_call;
71		
72		#define SDFGI_MAX_CASCADES 8
73		
74		/* Set 0: Base Pass (never changes) */
75		
76		#include "../light_data_inc.glsl"
77		
78		#include "../samplers_inc.glsl"
79		
80		layout(set = 0, binding = 2) uniform sampler shadow_sampler;
81		
82		layout(set = 0, binding = 3) uniform sampler decal_sampler;
83		
84		layout(set = 0, binding = 4) uniform sampler light_projector_sampler;
85		
86		#define INSTANCE_FLAGS_NON_UNIFORM_SCALE (1 << 4)
87		#define INSTANCE_FLAGS_USE_GI_BUFFERS (1 << 5)
88		#define INSTANCE_FLAGS_USE_SDFGI (1 << 6)
89		#define INSTANCE_FLAGS_USE_LIGHTMAP_CAPTURE (1 << 7)
90		#define INSTANCE_FLAGS_USE_LIGHTMAP (1 << 8)
91		#define INSTANCE_FLAGS_USE_SH_LIGHTMAP (1 << 9)
92		#define INSTANCE_FLAGS_USE_VOXEL_GI (1 << 10)
93		#define INSTANCE_FLAGS_PARTICLES (1 << 11)
94		#define INSTANCE_FLAGS_MULTIMESH (1 << 12)
95		#define INSTANCE_FLAGS_MULTIMESH_FORMAT_2D (1 << 13)
96		#define INSTANCE_FLAGS_MULTIMESH_HAS_COLOR (1 << 14)
97		#define INSTANCE_FLAGS_MULTIMESH_HAS_CUSTOM_DATA (1 << 15)
98		#define INSTANCE_FLAGS_PARTICLE_TRAIL_SHIFT 16
99		#define INSTANCE_FLAGS_FADE_SHIFT 24
100		//3 bits of stride
101		#define INSTANCE_FLAGS_PARTICLE_TRAIL_MASK 0xFF
102		
103		#define SCREEN_SPACE_EFFECTS_FLAGS_USE_SSAO 1
104		#define SCREEN_SPACE_EFFECTS_FLAGS_USE_SSIL 2
105		
106		layout(set = 0, binding = 5, std430) restrict readonly buffer OmniLights {
107			LightData data[];
108		}
109		omni_lights;
110		
111		layout(set = 0, binding = 6, std430) restrict readonly buffer SpotLights {
112			LightData data[];
113		}
114		spot_lights;
115		
116		layout(set = 0, binding = 7, std430) restrict readonly buffer ReflectionProbeData {
117			ReflectionData data[];
118		}
119		reflections;
120		
121		layout(set = 0, binding = 8, std140) uniform DirectionalLights {
122			DirectionalLightData data[MAX_DIRECTIONAL_LIGHT_DATA_STRUCTS];
123		}
124		directional_lights;
125		
126		#define LIGHTMAP_FLAG_USE_DIRECTION 1
127		#define LIGHTMAP_FLAG_USE_SPECULAR_DIRECTION 2
128		
129		struct Lightmap {
130			mat3 normal_xform;
131			vec3 pad;
132			float exposure_normalization;
133		};
134		
135		layout(set = 0, binding = 9, std140) restrict readonly buffer Lightmaps {
136			Lightmap data[];
137		}
138		lightmaps;
139		
140		struct LightmapCapture {
141			vec4 sh[9];
142		};
143		
144		layout(set = 0, binding = 10, std140) restrict readonly buffer LightmapCaptures {
145			LightmapCapture data[];
146		}
147		lightmap_captures;
148		
149		layout(set = 0, binding = 11) uniform texture2D decal_atlas;
150		layout(set = 0, binding = 12) uniform texture2D decal_atlas_srgb;
151		
152		layout(set = 0, binding = 13, std430) restrict readonly buffer Decals {
153			DecalData data[];
154		}
155		decals;
156		
157		layout(set = 0, binding = 14, std430) restrict readonly buffer GlobalShaderUniformData {
158			vec4 data[];
159		}
160		global_shader_uniforms;
161		
162		struct SDFVoxelGICascadeData {
163			vec3 position;
164			float to_probe;
165			ivec3 probe_world_offset;
166			float to_cell; // 1/bounds * grid_size
167			vec3 pad;
168			float exposure_normalization;
169		};
170		
171		layout(set = 0, binding = 15, std140) uniform SDFGI {
172			vec3 grid_size;
173			uint max_cascades;
174		
175			bool use_occlusion;
176			int probe_axis_size;
177			float probe_to_uvw;
178			float normal_bias;
179		
180			vec3 lightprobe_tex_pixel_size;
181			float energy;
182		
183			vec3 lightprobe_uv_offset;
184			float y_mult;
185		
186			vec3 occlusion_clamp;
187			uint pad3;
188		
189			vec3 occlusion_renormalize;
190			uint pad4;
191		
192			vec3 cascade_probe_size;
193			uint pad5;
194		
195			SDFVoxelGICascadeData cascades[SDFGI_MAX_CASCADES];
196		}
197		sdfgi;
198		
199		/* Set 1: Render Pass (changes per render pass) */
200		
201		layout(set = 1, binding = 0, std140) uniform SceneDataBlock {
202			SceneData data;
203			SceneData prev_data;
204		}
205		scene_data_block;
206		
207		struct ImplementationData {
208			uint cluster_shift;
209			uint cluster_width;
210			uint cluster_type_size;
211			uint max_cluster_element_count_div_32;
212		
213			uint ss_effects_flags;
214			float ssao_light_affect;
215			float ssao_ao_affect;
216			uint pad1;
217		
218			mat4 sdf_to_bounds;
219		
220			ivec3 sdf_offset;
221			uint pad2;
222		
223			ivec3 sdf_size;
224			bool gi_upscale_for_msaa;
225		
226			bool volumetric_fog_enabled;
227			float volumetric_fog_inv_length;
228			float volumetric_fog_detail_spread;
229			uint volumetric_fog_pad;
230		};
231		
232		layout(set = 1, binding = 1, std140) uniform ImplementationDataBlock {
233			ImplementationData data;
234		}
235		implementation_data_block;
236		
237		#define implementation_data implementation_data_block.data
238		
239		struct InstanceData {
240			mat4 transform;
241			mat4 prev_transform;
242			uint flags;
243			uint instance_uniforms_ofs; //base offset in global buffer for instance variables
244			uint gi_offset; //GI information when using lightmapping (VCT or lightmap index)
245			uint layer_mask;
246			vec4 lightmap_uv_scale;
247			vec4 compressed_aabb_position_pad; // Only .xyz is used. .w is padding.
248			vec4 compressed_aabb_size_pad; // Only .xyz is used. .w is padding.
249			vec4 uv_scale;
250		};
251		
252		layout(set = 1, binding = 2, std430) buffer restrict readonly InstanceDataBuffer {
253			InstanceData data[];
254		}
255		instances;
256		
257		#ifdef USE_RADIANCE_CUBEMAP_ARRAY
258		
259		layout(set = 1, binding = 3) uniform textureCubeArray radiance_cubemap;
260		
261		#else
262		
263		layout(set = 1, binding = 3) uniform textureCube radiance_cubemap;
264		
265		#endif
266		
267		layout(set = 1, binding = 4) uniform textureCubeArray reflection_atlas;
268		
269		layout(set = 1, binding = 5) uniform texture2D shadow_atlas;
270		
271		layout(set = 1, binding = 6) uniform texture2D directional_shadow_atlas;
272		
273		layout(set = 1, binding = 7) uniform texture2DArray lightmap_textures[MAX_LIGHTMAP_TEXTURES];
274		
275		layout(set = 1, binding = 8) uniform texture3D voxel_gi_textures[MAX_VOXEL_GI_INSTANCES];
276		
277		layout(set = 1, binding = 9, std430) buffer restrict readonly ClusterBuffer {
278			uint data[];
279		}
280		cluster_buffer;
281		
282		#ifdef MODE_RENDER_SDF
283		
284		layout(r16ui, set = 1, binding = 10) uniform restrict writeonly uimage3D albedo_volume_grid;
285		layout(r32ui, set = 1, binding = 11) uniform restrict writeonly uimage3D emission_grid;
286		layout(r32ui, set = 1, binding = 12) uniform restrict writeonly uimage3D emission_aniso_grid;
287		layout(r32ui, set = 1, binding = 13) uniform restrict uimage3D geom_facing_grid;
288		
289		//still need to be present for shaders that use it, so remap them to something
290		#define depth_buffer shadow_atlas
291		#define color_buffer shadow_atlas
292		#define normal_roughness_buffer shadow_atlas
293		
294		#define multiviewSampler sampler2D
295		#else
296		
297		#ifdef USE_MULTIVIEW
298		layout(set = 1, binding = 10) uniform texture2DArray depth_buffer;
299		layout(set = 1, binding = 11) uniform texture2DArray color_buffer;
300		layout(set = 1, binding = 12) uniform texture2DArray normal_roughness_buffer;
301		layout(set = 1, binding = 13) uniform texture2DArray ao_buffer;
302		layout(set = 1, binding = 14) uniform texture2DArray ambient_buffer;
303		layout(set = 1, binding = 15) uniform texture2DArray reflection_buffer;
304		#define multiviewSampler sampler2DArray
305		#else // USE_MULTIVIEW
306		layout(set = 1, binding = 10) uniform texture2D depth_buffer;
307		layout(set = 1, binding = 11) uniform texture2D color_buffer;
308		layout(set = 1, binding = 12) uniform texture2D normal_roughness_buffer;
309		layout(set = 1, binding = 13) uniform texture2D ao_buffer;
310		layout(set = 1, binding = 14) uniform texture2D ambient_buffer;
311		layout(set = 1, binding = 15) uniform texture2D reflection_buffer;
312		#define multiviewSampler sampler2D
313		#endif
314		layout(set = 1, binding = 16) uniform texture2DArray sdfgi_lightprobe_texture;
315		layout(set = 1, binding = 17) uniform texture3D sdfgi_occlusion_cascades;
316		
317		struct VoxelGIData {
318			mat4 xform; // 64 - 64
319		
320			vec3 bounds; // 12 - 76
321			float dynamic_range; // 4 - 80
322		
323			float bias; // 4 - 84
324			float normal_bias; // 4 - 88
325			bool blend_ambient; // 4 - 92
326			uint mipmaps; // 4 - 96
327		
328			vec3 pad; // 12 - 108
329			float exposure_normalization; // 4 - 112
330		};
331		
332		layout(set = 1, binding = 18, std140) uniform VoxelGIs {
333			VoxelGIData data[MAX_VOXEL_GI_INSTANCES];
334		}
335		voxel_gi_instances;
336		
337		layout(set = 1, binding = 19) uniform texture3D volumetric_fog_texture;
338		
339		#ifdef USE_MULTIVIEW
340		layout(set = 1, binding = 20) uniform texture2DArray ssil_buffer;
341		#else
342		layout(set = 1, binding = 20) uniform texture2D ssil_buffer;
343		#endif // USE_MULTIVIEW
344		
345		#endif
346		
347		/* Set 2 Skeleton & Instancing (can change per item) */
348		
349		layout(set = 2, binding = 0, std430) restrict readonly buffer Transforms {
350			vec4 data[];
351		}
352		transforms;
353		
354		/* Set 3 User Material */
355		
356		
357		/* Varyings */
358		
359		layout(location = 0) in vec3 vertex_interp;
360		
361		#ifdef NORMAL_USED
362		layout(location = 1) in vec3 normal_interp;
363		#endif
364		
365		#if defined(COLOR_USED)
366		layout(location = 2) in vec4 color_interp;
367		#endif
368		
369		#ifdef UV_USED
370		layout(location = 3) in vec2 uv_interp;
371		#endif
372		
373		#if defined(UV2_USED) || defined(USE_LIGHTMAP)
374		layout(location = 4) in vec2 uv2_interp;
375		#endif
376		
377		#ifdef TANGENT_USED
378		layout(location = 5) in vec3 tangent_interp;
379		layout(location = 6) in vec3 binormal_interp;
380		#endif
381		
382		#ifdef MOTION_VECTORS
383		layout(location = 7) in vec4 screen_position;
384		layout(location = 8) in vec4 prev_screen_position;
385		#endif
386		
387		#ifdef MODE_DUAL_PARABOLOID
388		
389		layout(location = 9) in float dp_clip;
390		
391		#endif
392		
393		layout(location = 10) in flat uint instance_index_interp;
394		
395		#ifdef USE_MULTIVIEW
396		#ifdef has_VK_KHR_multiview
397		#define ViewIndex gl_ViewIndex
398		#else // has_VK_KHR_multiview
399		// !BAS! This needs to become an input once we implement our fallback!
400		#define ViewIndex 0
401		#endif // has_VK_KHR_multiview
402		vec3 multiview_uv(vec2 uv) {
403			return vec3(uv, ViewIndex);
404		}
405		layout(location = 11) in vec4 combined_projected;
406		#else // USE_MULTIVIEW
407		// Set to zero, not supported in non stereo
408		#define ViewIndex 0
409		vec2 multiview_uv(vec2 uv) {
410			return uv;
411		}
412		#endif //USE_MULTIVIEW
413		
414		//defines to keep compatibility with vertex
415		
416		#ifdef USE_MULTIVIEW
417		#define projection_matrix scene_data.projection_matrix_view[ViewIndex]
418		#define inv_projection_matrix scene_data.inv_projection_matrix_view[ViewIndex]
419		#else
420		#define projection_matrix scene_data.projection_matrix
421		#define inv_projection_matrix scene_data.inv_projection_matrix
422		#endif
423		
424		#define global_time scene_data_block.data.time
425		
426		#if defined(ENABLE_SSS) && defined(ENABLE_TRANSMITTANCE)
427		//both required for transmittance to be enabled
428		#define LIGHT_TRANSMITTANCE_USED
429		#endif
430		
431		#ifdef MATERIAL_UNIFORMS_USED
432		layout(set = MATERIAL_UNIFORM_SET, binding = 0, std140) uniform MaterialUniforms{
433		
434		#MATERIAL_UNIFORMS
435		
436		} material;
437		#endif
438		
439		#GLOBALS
440		
441		#ifdef MODE_RENDER_DEPTH
442		
443		#ifdef MODE_RENDER_MATERIAL
444		
445		layout(location = 0) out vec4 albedo_output_buffer;
446		layout(location = 1) out vec4 normal_output_buffer;
447		layout(location = 2) out vec4 orm_output_buffer;
448		layout(location = 3) out vec4 emission_output_buffer;
449		layout(location = 4) out float depth_output_buffer;
450		
451		#endif // MODE_RENDER_MATERIAL
452		
453		#ifdef MODE_RENDER_NORMAL_ROUGHNESS
454		layout(location = 0) out vec4 normal_roughness_output_buffer;
455		
456		#ifdef MODE_RENDER_VOXEL_GI
457		layout(location = 1) out uvec2 voxel_gi_buffer;
458		#endif
459		
460		#endif //MODE_RENDER_NORMAL
461		#else // RENDER DEPTH
462		
463		#ifdef MODE_SEPARATE_SPECULAR
464		
465		layout(location = 0) out vec4 diffuse_buffer; //diffuse (rgb) and roughness
466		layout(location = 1) out vec4 specular_buffer; //specular and SSS (subsurface scatter)
467		#else
468		
469		layout(location = 0) out vec4 frag_color;
470		#endif // MODE_SEPARATE_SPECULAR
471		
472		#endif // RENDER DEPTH
473		
474		#ifdef MOTION_VECTORS
475		layout(location = 2) out vec2 motion_vector;
476		#endif
477		
478		
479		#ifdef ALPHA_HASH_USED
480		
481		float hash_2d(vec2 p) {
482			return fract(1.0e4 * sin(17.0 * p.x + 0.1 * p.y) *
483					(0.1 + abs(sin(13.0 * p.y + p.x))));
484		}
485		
486		float hash_3d(vec3 p) {
487			return hash_2d(vec2(hash_2d(p.xy), p.z));
488		}
489		
490		float compute_alpha_hash_threshold(vec3 pos, float hash_scale) {
491			vec3 dx = dFdx(pos);
492			vec3 dy = dFdy(pos);
493		
494			float delta_max_sqr = max(length(dx), length(dy));
495			float pix_scale = 1.0 / (hash_scale * delta_max_sqr);
496		
497			vec2 pix_scales =
498					vec2(exp2(floor(log2(pix_scale))), exp2(ceil(log2(pix_scale))));
499		
500			vec2 a_thresh = vec2(hash_3d(floor(pix_scales.x * pos.xyz)),
501					hash_3d(floor(pix_scales.y * pos.xyz)));
502		
503			float lerp_factor = fract(log2(pix_scale));
504		
505			float a_interp = (1.0 - lerp_factor) * a_thresh.x + lerp_factor * a_thresh.y;
506		
507			float min_lerp = min(lerp_factor, 1.0 - lerp_factor);
508		
509			vec3 cases = vec3(a_interp * a_interp / (2.0 * min_lerp * (1.0 - min_lerp)),
510					(a_interp - 0.5 * min_lerp) / (1.0 - min_lerp),
511					1.0 - ((1.0 - a_interp) * (1.0 - a_interp) / (2.0 * min_lerp * (1.0 - min_lerp))));
512		
513			float alpha_hash_threshold =
514					(a_interp < (1.0 - min_lerp)) ? ((a_interp < min_lerp) ? cases.x : cases.y) : cases.z;
515		
516			return clamp(alpha_hash_threshold, 0.00001, 1.0);
517		}
518		
519		#endif // ALPHA_HASH_USED
520		
521		#ifdef ALPHA_ANTIALIASING_EDGE_USED
522		
523		float calc_mip_level(vec2 texture_coord) {
524			vec2 dx = dFdx(texture_coord);
525			vec2 dy = dFdy(texture_coord);
526			float delta_max_sqr = max(dot(dx, dx), dot(dy, dy));
527			return max(0.0, 0.5 * log2(delta_max_sqr));
528		}
529		
530		float compute_alpha_antialiasing_edge(float input_alpha, vec2 texture_coord, float alpha_edge) {
531			input_alpha *= 1.0 + max(0, calc_mip_level(texture_coord)) * 0.25; // 0.25 mip scale, magic number
532			input_alpha = (input_alpha - alpha_edge) / max(fwidth(input_alpha), 0.0001) + 0.5;
533			return clamp(input_alpha, 0.0, 1.0);
534		}
535		
536		#endif // ALPHA_ANTIALIASING_USED
537		
538		
539		#if !defined(MODE_RENDER_DEPTH) && !defined(MODE_UNSHADED)
540		
541		// Default to SPECULAR_SCHLICK_GGX.
542		#if !defined(SPECULAR_DISABLED) && !defined(SPECULAR_SCHLICK_GGX) && !defined(SPECULAR_TOON)
543		#define SPECULAR_SCHLICK_GGX
544		#endif
545		
546		
547		// Functions related to lighting
548		
549		float D_GGX(float cos_theta_m, float alpha) {
550			float a = cos_theta_m * alpha;
551			float k = alpha / (1.0 - cos_theta_m * cos_theta_m + a * a);
552			return k * k * (1.0 / M_PI);
553		}
554		
555		// From Earl Hammon, Jr. "PBR Diffuse Lighting for GGX+Smith Microsurfaces" https://www.gdcvault.com/play/1024478/PBR-Diffuse-Lighting-for-GGX
556		float V_GGX(float NdotL, float NdotV, float alpha) {
557			return 0.5 / mix(2.0 * NdotL * NdotV, NdotL + NdotV, alpha);
558		}
559		
560		float D_GGX_anisotropic(float cos_theta_m, float alpha_x, float alpha_y, float cos_phi, float sin_phi) {
561			float alpha2 = alpha_x * alpha_y;
562			highp vec3 v = vec3(alpha_y * cos_phi, alpha_x * sin_phi, alpha2 * cos_theta_m);
563			highp float v2 = dot(v, v);
564			float w2 = alpha2 / v2;
565			float D = alpha2 * w2 * w2 * (1.0 / M_PI);
566			return D;
567		}
568		
569		float V_GGX_anisotropic(float alpha_x, float alpha_y, float TdotV, float TdotL, float BdotV, float BdotL, float NdotV, float NdotL) {
570			float Lambda_V = NdotL * length(vec3(alpha_x * TdotV, alpha_y * BdotV, NdotV));
571			float Lambda_L = NdotV * length(vec3(alpha_x * TdotL, alpha_y * BdotL, NdotL));
572			return 0.5 / (Lambda_V + Lambda_L);
573		}
574		
575		float SchlickFresnel(float u) {
576			float m = 1.0 - u;
577			float m2 = m * m;
578			return m2 * m2 * m; // pow(m,5)
579		}
580		
581		vec3 F0(float metallic, float specular, vec3 albedo) {
582			float dielectric = 0.16 * specular * specular;
583			// use albedo * metallic as colored specular reflectance at 0 angle for metallic materials;
584			// see https://google.github.io/filament/Filament.md.html
585			return mix(vec3(dielectric), albedo, vec3(metallic));
586		}
587		
588		void light_compute(vec3 N, vec3 L, vec3 V, float A, vec3 light_color, bool is_directional, float attenuation, vec3 f0, uint orms, float specular_amount, vec3 albedo, inout float alpha,
589		#ifdef LIGHT_BACKLIGHT_USED
590				vec3 backlight,
591		#endif
592		#ifdef LIGHT_TRANSMITTANCE_USED
593				vec4 transmittance_color,
594				float transmittance_depth,
595				float transmittance_boost,
596				float transmittance_z,
597		#endif
598		#ifdef LIGHT_RIM_USED
599				float rim, float rim_tint,
600		#endif
601		#ifdef LIGHT_CLEARCOAT_USED
602				float clearcoat, float clearcoat_roughness, vec3 vertex_normal,
603		#endif
604		#ifdef LIGHT_ANISOTROPY_USED
605				vec3 B, vec3 T, float anisotropy,
606		#endif
607				inout vec3 diffuse_light, inout vec3 specular_light) {
608		
609			vec4 orms_unpacked = unpackUnorm4x8(orms);
610		
611			float roughness = orms_unpacked.y;
612			float metallic = orms_unpacked.z;
613		
614		#if defined(LIGHT_CODE_USED)
615			// light is written by the light shader
616		
617			mat4 inv_view_matrix = scene_data_block.data.inv_view_matrix;
618		
619		#ifdef USING_MOBILE_RENDERER
620			mat4 read_model_matrix = instances.data[draw_call.instance_index].transform;
621		#else
622			mat4 read_model_matrix = instances.data[instance_index_interp].transform;
623		#endif
624		
625			mat4 read_view_matrix = scene_data_block.data.view_matrix;
626		
627		#undef projection_matrix
628		#define projection_matrix scene_data_block.data.projection_matrix
629		#undef inv_projection_matrix
630		#define inv_projection_matrix scene_data_block.data.inv_projection_matrix
631		
632			vec2 read_viewport_size = scene_data_block.data.viewport_size;
633		
634			vec3 normal = N;
635			vec3 light = L;
636			vec3 view = V;
637		
638		#CODE : LIGHT
639		
640		#else
641		
642			float NdotL = min(A + dot(N, L), 1.0);
643			float cNdotL = max(NdotL, 0.0); // clamped NdotL
644			float NdotV = dot(N, V);
645			float cNdotV = max(NdotV, 1e-4);
646		
647		#if defined(DIFFUSE_BURLEY) || defined(SPECULAR_SCHLICK_GGX) || defined(LIGHT_CLEARCOAT_USED)
648			vec3 H = normalize(V + L);
649		#endif
650		
651		#if defined(SPECULAR_SCHLICK_GGX)
652			float cNdotH = clamp(A + dot(N, H), 0.0, 1.0);
653		#endif
654		
655		#if defined(DIFFUSE_BURLEY) || defined(SPECULAR_SCHLICK_GGX) || defined(LIGHT_CLEARCOAT_USED)
656			float cLdotH = clamp(A + dot(L, H), 0.0, 1.0);
657		#endif
658		
659			if (metallic < 1.0) {
660				float diffuse_brdf_NL; // BRDF times N.L for calculating diffuse radiance
661		
662		#if defined(DIFFUSE_LAMBERT_WRAP)
663				// Energy conserving lambert wrap shader.
664				// https://web.archive.org/web/20210228210901/http://blog.stevemcauley.com/2011/12/03/energy-conserving-wrapped-diffuse/
665				diffuse_brdf_NL = max(0.0, (NdotL + roughness) / ((1.0 + roughness) * (1.0 + roughness))) * (1.0 / M_PI);
666		#elif defined(DIFFUSE_TOON)
667		
668				diffuse_brdf_NL = smoothstep(-roughness, max(roughness, 0.01), NdotL) * (1.0 / M_PI);
669		
670		#elif defined(DIFFUSE_BURLEY)
671		
672				{
673					float FD90_minus_1 = 2.0 * cLdotH * cLdotH * roughness - 0.5;
674					float FdV = 1.0 + FD90_minus_1 * SchlickFresnel(cNdotV);
675					float FdL = 1.0 + FD90_minus_1 * SchlickFresnel(cNdotL);
676					diffuse_brdf_NL = (1.0 / M_PI) * FdV * FdL * cNdotL;
677					/*
678					float energyBias = mix(roughness, 0.0, 0.5);
679					float energyFactor = mix(roughness, 1.0, 1.0 / 1.51);
680					float fd90 = energyBias + 2.0 * VoH * VoH * roughness;
681					float f0 = 1.0;
682					float lightScatter = f0 + (fd90 - f0) * pow(1.0 - cNdotL, 5.0);
683					float viewScatter = f0 + (fd90 - f0) * pow(1.0 - cNdotV, 5.0);
684		
685					diffuse_brdf_NL = lightScatter * viewScatter * energyFactor;
686					*/
687				}
688		#else
689				// lambert
690				diffuse_brdf_NL = cNdotL * (1.0 / M_PI);
691		#endif
692		
693				diffuse_light += light_color * diffuse_brdf_NL * attenuation;
694		
695		#if defined(LIGHT_BACKLIGHT_USED)
696				diffuse_light += light_color * (vec3(1.0 / M_PI) - diffuse_brdf_NL) * backlight * attenuation;
697		#endif
698		
699		#if defined(LIGHT_RIM_USED)
700				// Epsilon min to prevent pow(0, 0) singularity which results in undefined behavior.
701				float rim_light = pow(max(1e-4, 1.0 - cNdotV), max(0.0, (1.0 - roughness) * 16.0));
702				diffuse_light += rim_light * rim * mix(vec3(1.0), albedo, rim_tint) * light_color;
703		#endif
704		
705		#ifdef LIGHT_TRANSMITTANCE_USED
706		
707				{
708		#ifdef SSS_MODE_SKIN
709					float scale = 8.25 / transmittance_depth;
710					float d = scale * abs(transmittance_z);
711					float dd = -d * d;
712					vec3 profile = vec3(0.233, 0.455, 0.649) * exp(dd / 0.0064) +
713							vec3(0.1, 0.336, 0.344) * exp(dd / 0.0484) +
714							vec3(0.118, 0.198, 0.0) * exp(dd / 0.187) +
715							vec3(0.113, 0.007, 0.007) * exp(dd / 0.567) +
716							vec3(0.358, 0.004, 0.0) * exp(dd / 1.99) +
717							vec3(0.078, 0.0, 0.0) * exp(dd / 7.41);
718		
719					diffuse_light += profile * transmittance_color.a * light_color * clamp(transmittance_boost - NdotL, 0.0, 1.0) * (1.0 / M_PI);
720		#else
721		
722					float scale = 8.25 / transmittance_depth;
723					float d = scale * abs(transmittance_z);
724					float dd = -d * d;
725					diffuse_light += exp(dd) * transmittance_color.rgb * transmittance_color.a * light_color * clamp(transmittance_boost - NdotL, 0.0, 1.0) * (1.0 / M_PI);
726		#endif
727				}
728		#else
729		
730		#endif //LIGHT_TRANSMITTANCE_USED
731			}
732		
733			if (roughness > 0.0) { // FIXME: roughness == 0 should not disable specular light entirely
734		
735				// D
736		
737		#if defined(SPECULAR_TOON)
738		
739				vec3 R = normalize(-reflect(L, N));
740				float RdotV = dot(R, V);
741				float mid = 1.0 - roughness;
742				mid *= mid;
743				float intensity = smoothstep(mid - roughness * 0.5, mid + roughness * 0.5, RdotV) * mid;
744				diffuse_light += light_color * intensity * attenuation * specular_amount; // write to diffuse_light, as in toon shading you generally want no reflection
745		
746		#elif defined(SPECULAR_DISABLED)
747				// none..
748		
749		#elif defined(SPECULAR_SCHLICK_GGX)
750				// shlick+ggx as default
751				float alpha_ggx = roughness * roughness;
752		#if defined(LIGHT_ANISOTROPY_USED)
753		
754				float aspect = sqrt(1.0 - anisotropy * 0.9);
755				float ax = alpha_ggx / aspect;
756				float ay = alpha_ggx * aspect;
757				float XdotH = dot(T, H);
758				float YdotH = dot(B, H);
759				float D = D_GGX_anisotropic(cNdotH, ax, ay, XdotH, YdotH);
760				float G = V_GGX_anisotropic(ax, ay, dot(T, V), dot(T, L), dot(B, V), dot(B, L), cNdotV, cNdotL);
761		#else // LIGHT_ANISOTROPY_USED
762				float D = D_GGX(cNdotH, alpha_ggx);
763				float G = V_GGX(cNdotL, cNdotV, alpha_ggx);
764		#endif // LIGHT_ANISOTROPY_USED
765			   // F
766				float cLdotH5 = SchlickFresnel(cLdotH);
767				// Calculate Fresnel using specular occlusion term from Filament:
768				// https://google.github.io/filament/Filament.html#lighting/occlusion/specularocclusion
769				float f90 = clamp(dot(f0, vec3(50.0 * 0.33)), metallic, 1.0);
770				vec3 F = f0 + (f90 - f0) * cLdotH5;
771		
772				vec3 specular_brdf_NL = cNdotL * D * F * G;
773		
774				specular_light += specular_brdf_NL * light_color * attenuation * specular_amount;
775		#endif
776		
777		#if defined(LIGHT_CLEARCOAT_USED)
778				// Clearcoat ignores normal_map, use vertex normal instead
779				float ccNdotL = max(min(A + dot(vertex_normal, L), 1.0), 0.0);
780				float ccNdotH = clamp(A + dot(vertex_normal, H), 0.0, 1.0);
781				float ccNdotV = max(dot(vertex_normal, V), 1e-4);
782		
783		#if !defined(SPECULAR_SCHLICK_GGX)
784				float cLdotH5 = SchlickFresnel(cLdotH);
785		#endif
786				float Dr = D_GGX(ccNdotH, mix(0.001, 0.1, clearcoat_roughness));
787				float Gr = 0.25 / (cLdotH * cLdotH);
788				float Fr = mix(.04, 1.0, cLdotH5);
789				float clearcoat_specular_brdf_NL = clearcoat * Gr * Fr * Dr * cNdotL;
790		
791				specular_light += clearcoat_specular_brdf_NL * light_color * attenuation * specular_amount;
792				// TODO: Clearcoat adds light to the scene right now (it is non-energy conserving), both diffuse and specular need to be scaled by (1.0 - FR)
793				// but to do so we need to rearrange this entire function
794		#endif // LIGHT_CLEARCOAT_USED
795			}
796		
797		#ifdef USE_SHADOW_TO_OPACITY
798			alpha = min(alpha, clamp(1.0 - attenuation, 0.0, 1.0));
799		#endif
800		
801		#endif //defined(LIGHT_CODE_USED)
802		}
803		
804		#ifndef SHADOWS_DISABLED
805		
806		// Interleaved Gradient Noise
807		// https://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare
808		float quick_hash(vec2 pos) {
809			const vec3 magic = vec3(0.06711056f, 0.00583715f, 52.9829189f);
810			return fract(magic.z * fract(dot(pos, magic.xy)));
811		}
812		
813		float sample_directional_pcf_shadow(texture2D shadow, vec2 shadow_pixel_size, vec4 coord) {
814			vec2 pos = coord.xy;
815			float depth = coord.z;
816		
817			//if only one sample is taken, take it from the center
818			if (sc_directional_soft_shadow_samples == 0) {
819				return textureProj(sampler2DShadow(shadow, shadow_sampler), vec4(pos, depth, 1.0));
820			}
821		
822			mat2 disk_rotation;
823			{
824				float r = quick_hash(gl_FragCoord.xy) * 2.0 * M_PI;
825				float sr = sin(r);
826				float cr = cos(r);
827				disk_rotation = mat2(vec2(cr, -sr), vec2(sr, cr));
828			}
829		
830			float avg = 0.0;
831		
832			for (uint i = 0; i < sc_directional_soft_shadow_samples; i++) {
833				avg += textureProj(sampler2DShadow(shadow, shadow_sampler), vec4(pos + shadow_pixel_size * (disk_rotation * scene_data_block.data.directional_soft_shadow_kernel[i].xy), depth, 1.0));
834			}
835		
836			return avg * (1.0 / float(sc_directional_soft_shadow_samples));
837		}
838		
839		float sample_pcf_shadow(texture2D shadow, vec2 shadow_pixel_size, vec3 coord) {
840			vec2 pos = coord.xy;
841			float depth = coord.z;
842		
843			//if only one sample is taken, take it from the center
844			if (sc_soft_shadow_samples == 0) {
845				return textureProj(sampler2DShadow(shadow, shadow_sampler), vec4(pos, depth, 1.0));
846			}
847		
848			mat2 disk_rotation;
849			{
850				float r = quick_hash(gl_FragCoord.xy) * 2.0 * M_PI;
851				float sr = sin(r);
852				float cr = cos(r);
853				disk_rotation = mat2(vec2(cr, -sr), vec2(sr, cr));
854			}
855		
856			float avg = 0.0;
857		
858			for (uint i = 0; i < sc_soft_shadow_samples; i++) {
859				avg += textureProj(sampler2DShadow(shadow, shadow_sampler), vec4(pos + shadow_pixel_size * (disk_rotation * scene_data_block.data.soft_shadow_kernel[i].xy), depth, 1.0));
860			}
861		
862			return avg * (1.0 / float(sc_soft_shadow_samples));
863		}
864		
865		float sample_omni_pcf_shadow(texture2D shadow, float blur_scale, vec2 coord, vec4 uv_rect, vec2 flip_offset, float depth) {
866			//if only one sample is taken, take it from the center
867			if (sc_soft_shadow_samples == 0) {
868				vec2 pos = coord * 0.5 + 0.5;
869				pos = uv_rect.xy + pos * uv_rect.zw;
870				return textureProj(sampler2DShadow(shadow, shadow_sampler), vec4(pos, depth, 1.0));
871			}
872		
873			mat2 disk_rotation;
874			{
875				float r = quick_hash(gl_FragCoord.xy) * 2.0 * M_PI;
876				float sr = sin(r);
877				float cr = cos(r);
878				disk_rotation = mat2(vec2(cr, -sr), vec2(sr, cr));
879			}
880		
881			float avg = 0.0;
882			vec2 offset_scale = blur_scale * 2.0 * scene_data_block.data.shadow_atlas_pixel_size / uv_rect.zw;
883		
884			for (uint i = 0; i < sc_soft_shadow_samples; i++) {
885				vec2 offset = offset_scale * (disk_rotation * scene_data_block.data.soft_shadow_kernel[i].xy);
886				vec2 sample_coord = coord + offset;
887		
888				float sample_coord_length_sqaured = dot(sample_coord, sample_coord);
889				bool do_flip = sample_coord_length_sqaured > 1.0;
890		
891				if (do_flip) {
892					float len = sqrt(sample_coord_length_sqaured);
893					sample_coord = sample_coord * (2.0 / len - 1.0);
894				}
895		
896				sample_coord = sample_coord * 0.5 + 0.5;
897				sample_coord = uv_rect.xy + sample_coord * uv_rect.zw;
898		
899				if (do_flip) {
900					sample_coord += flip_offset;
901				}
902				avg += textureProj(sampler2DShadow(shadow, shadow_sampler), vec4(sample_coord, depth, 1.0));
903			}
904		
905			return avg * (1.0 / float(sc_soft_shadow_samples));
906		}
907		
908		float sample_directional_soft_shadow(texture2D shadow, vec3 pssm_coord, vec2 tex_scale) {
909			//find blocker
910			float blocker_count = 0.0;
911			float blocker_average = 0.0;
912		
913			mat2 disk_rotation;
914			{
915				float r = quick_hash(gl_FragCoord.xy) * 2.0 * M_PI;
916				float sr = sin(r);
917				float cr = cos(r);
918				disk_rotation = mat2(vec2(cr, -sr), vec2(sr, cr));
919			}
920		
921			for (uint i = 0; i < sc_directional_penumbra_shadow_samples; i++) {
922				vec2 suv = pssm_coord.xy + (disk_rotation * scene_data_block.data.directional_penumbra_shadow_kernel[i].xy) * tex_scale;
923				float d = textureLod(sampler2D(shadow, SAMPLER_LINEAR_CLAMP), suv, 0.0).r;
924				if (d < pssm_coord.z) {
925					blocker_average += d;
926					blocker_count += 1.0;
927				}
928			}
929		
930			if (blocker_count > 0.0) {
931				//blockers found, do soft shadow
932				blocker_average /= blocker_count;
933				float penumbra = (pssm_coord.z - blocker_average) / blocker_average;
934				tex_scale *= penumbra;
935		
936				float s = 0.0;
937				for (uint i = 0; i < sc_directional_penumbra_shadow_samples; i++) {
938					vec2 suv = pssm_coord.xy + (disk_rotation * scene_data_block.data.directional_penumbra_shadow_kernel[i].xy) * tex_scale;
939					s += textureProj(sampler2DShadow(shadow, shadow_sampler), vec4(suv, pssm_coord.z, 1.0));
940				}
941		
942				return s / float(sc_directional_penumbra_shadow_samples);
943		
944			} else {
945				//no blockers found, so no shadow
946				return 1.0;
947			}
948		}
949		
950		#endif // SHADOWS_DISABLED
951		
952		float get_omni_attenuation(float distance, float inv_range, float decay) {
953			float nd = distance * inv_range;
954			nd *= nd;
955			nd *= nd; // nd^4
956			nd = max(1.0 - nd, 0.0);
957			nd *= nd; // nd^2
958			return nd * pow(max(distance, 0.0001), -decay);
959		}
960		
961		float light_process_omni_shadow(uint idx, vec3 vertex, vec3 normal) {
962		#ifndef SHADOWS_DISABLED
963			if (omni_lights.data[idx].shadow_opacity > 0.001) {
964				// there is a shadowmap
965				vec2 texel_size = scene_data_block.data.shadow_atlas_pixel_size;
966				vec4 base_uv_rect = omni_lights.data[idx].atlas_rect;
967				base_uv_rect.xy += texel_size;
968				base_uv_rect.zw -= texel_size * 2.0;
969		
970				// Omni lights use direction.xy to store to store the offset between the two paraboloid regions
971				vec2 flip_offset = omni_lights.data[idx].direction.xy;
972		
973				vec3 local_vert = (omni_lights.data[idx].shadow_matrix * vec4(vertex, 1.0)).xyz;
974		
975				float shadow_len = length(local_vert); //need to remember shadow len from here
976				vec3 shadow_dir = normalize(local_vert);
977		
978				vec3 local_normal = normalize(mat3(omni_lights.data[idx].shadow_matrix) * normal);
979				vec3 normal_bias = local_normal * omni_lights.data[idx].shadow_normal_bias * (1.0 - abs(dot(local_normal, shadow_dir)));
980		
981				float shadow;
982		
983				if (sc_use_light_soft_shadows && omni_lights.data[idx].soft_shadow_size > 0.0) {
984					//soft shadow
985		
986					//find blocker
987		
988					float blocker_count = 0.0;
989					float blocker_average = 0.0;
990		
991					mat2 disk_rotation;
992					{
993						float r = quick_hash(gl_FragCoord.xy) * 2.0 * M_PI;
994						float sr = sin(r);
995						float cr = cos(r);
996						disk_rotation = mat2(vec2(cr, -sr), vec2(sr, cr));
997					}
998		
999					vec3 basis_normal = shadow_dir;
1000					vec3 v0 = abs(basis_normal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
1001					vec3 tangent = normalize(cross(v0, basis_normal));
1002					vec3 bitangent = normalize(cross(tangent, basis_normal));
1003					float z_norm = shadow_len * omni_lights.data[idx].inv_radius;
1004		
1005					tangent *= omni_lights.data[idx].soft_shadow_size * omni_lights.data[idx].soft_shadow_scale;
1006					bitangent *= omni_lights.data[idx].soft_shadow_size * omni_lights.data[idx].soft_shadow_scale;
1007		
1008					for (uint i = 0; i < sc_penumbra_shadow_samples; i++) {
1009						vec2 disk = disk_rotation * scene_data_block.data.penumbra_shadow_kernel[i].xy;
1010		
1011						vec3 pos = local_vert + tangent * disk.x + bitangent * disk.y;
1012		
1013						pos = normalize(pos);
1014		
1015						vec4 uv_rect = base_uv_rect;
1016		
1017						if (pos.z >= 0.0) {
1018							uv_rect.xy += flip_offset;
1019						}
1020		
1021						pos.z = 1.0 + abs(pos.z);
1022						pos.xy /= pos.z;
1023		
1024						pos.xy = pos.xy * 0.5 + 0.5;
1025						pos.xy = uv_rect.xy + pos.xy * uv_rect.zw;
1026		
1027						float d = textureLod(sampler2D(shadow_atlas, SAMPLER_LINEAR_CLAMP), pos.xy, 0.0).r;
1028						if (d < z_norm) {
1029							blocker_average += d;
1030							blocker_count += 1.0;
1031						}
1032					}
1033		
1034					if (blocker_count > 0.0) {
1035						//blockers found, do soft shadow
1036						blocker_average /= blocker_count;
1037						float penumbra = (z_norm - blocker_average) / blocker_average;
1038						tangent *= penumbra;
1039						bitangent *= penumbra;
1040		
1041						z_norm -= omni_lights.data[idx].inv_radius * omni_lights.data[idx].shadow_bias;
1042		
1043						shadow = 0.0;
1044						for (uint i = 0; i < sc_penumbra_shadow_samples; i++) {
1045							vec2 disk = disk_rotation * scene_data_block.data.penumbra_shadow_kernel[i].xy;
1046							vec3 pos = local_vert + tangent * disk.x + bitangent * disk.y;
1047		
1048							pos = normalize(pos);
1049							pos = normalize(pos + normal_bias);
1050		
1051							vec4 uv_rect = base_uv_rect;
1052		
1053							if (pos.z >= 0.0) {
1054								uv_rect.xy += flip_offset;
1055							}
1056		
1057							pos.z = 1.0 + abs(pos.z);
1058							pos.xy /= pos.z;
1059		
1060							pos.xy = pos.xy * 0.5 + 0.5;
1061							pos.xy = uv_rect.xy + pos.xy * uv_rect.zw;
1062							shadow += textureProj(sampler2DShadow(shadow_atlas, shadow_sampler), vec4(pos.xy, z_norm, 1.0));
1063						}
1064		
1065						shadow /= float(sc_penumbra_shadow_samples);
1066						shadow = mix(1.0, shadow, omni_lights.data[idx].shadow_opacity);
1067		
1068					} else {
1069						//no blockers found, so no shadow
1070						shadow = 1.0;
1071					}
1072				} else {
1073					vec4 uv_rect = base_uv_rect;
1074		
1075					vec3 shadow_sample = normalize(shadow_dir + normal_bias);
1076					if (shadow_sample.z >= 0.0) {
1077						uv_rect.xy += flip_offset;
1078						flip_offset *= -1.0;
1079					}
1080		
1081					shadow_sample.z = 1.0 + abs(shadow_sample.z);
1082					vec2 pos = shadow_sample.xy / shadow_sample.z;
1083					float depth = shadow_len - omni_lights.data[idx].shadow_bias;
1084					depth *= omni_lights.data[idx].inv_radius;
1085					shadow = mix(1.0, sample_omni_pcf_shadow(shadow_atlas, omni_lights.data[idx].soft_shadow_scale / shadow_sample.z, pos, uv_rect, flip_offset, depth), omni_lights.data[idx].shadow_opacity);
1086				}
1087		
1088				return shadow;
1089			}
1090		#endif
1091		
1092			return 1.0;
1093		}
1094		
1095		void light_process_omni(uint idx, vec3 vertex, vec3 eye_vec, vec3 normal, vec3 vertex_ddx, vec3 vertex_ddy, vec3 f0, uint orms, float shadow, vec3 albedo, inout float alpha,
1096		#ifdef LIGHT_BACKLIGHT_USED
1097				vec3 backlight,
1098		#endif
1099		#ifdef LIGHT_TRANSMITTANCE_USED
1100				vec4 transmittance_color,
1101				float transmittance_depth,
1102				float transmittance_boost,
1103		#endif
1104		#ifdef LIGHT_RIM_USED
1105				float rim, float rim_tint,
1106		#endif
1107		#ifdef LIGHT_CLEARCOAT_USED
1108				float clearcoat, float clearcoat_roughness, vec3 vertex_normal,
1109		#endif
1110		#ifdef LIGHT_ANISOTROPY_USED
1111				vec3 binormal, vec3 tangent, float anisotropy,
1112		#endif
1113				inout vec3 diffuse_light, inout vec3 specular_light) {
1114			vec3 light_rel_vec = omni_lights.data[idx].position - vertex;
1115			float light_length = length(light_rel_vec);
1116			float omni_attenuation = get_omni_attenuation(light_length, omni_lights.data[idx].inv_radius, omni_lights.data[idx].attenuation);
1117			float light_attenuation = omni_attenuation;
1118			vec3 color = omni_lights.data[idx].color;
1119		
1120			float size_A = 0.0;
1121		
1122			if (sc_use_light_soft_shadows && omni_lights.data[idx].size > 0.0) {
1123				float t = omni_lights.data[idx].size / max(0.001, light_length);
1124				size_A = max(0.0, 1.0 - 1 / sqrt(1 + t * t));
1125			}
1126		
1127		#ifdef LIGHT_TRANSMITTANCE_USED
1128			float transmittance_z = transmittance_depth; //no transmittance by default
1129			transmittance_color.a *= light_attenuation;
1130			{
1131				vec4 clamp_rect = omni_lights.data[idx].atlas_rect;
1132		
1133				//redo shadowmapping, but shrink the model a bit to avoid artifacts
1134				vec4 splane = (omni_lights.data[idx].shadow_matrix * vec4(vertex - normalize(normal_interp) * omni_lights.data[idx].transmittance_bias, 1.0));
1135		
1136				float shadow_len = length(splane.xyz);
1137				splane.xyz = normalize(splane.xyz);
1138		
1139				if (splane.z >= 0.0) {
1140					splane.z += 1.0;
1141					clamp_rect.y += clamp_rect.w;
1142				} else {
1143					splane.z = 1.0 - splane.z;
1144				}
1145		
1146				splane.xy /= splane.z;
1147		
1148				splane.xy = splane.xy * 0.5 + 0.5;
1149				splane.z = shadow_len * omni_lights.data[idx].inv_radius;
1150				splane.xy = clamp_rect.xy + splane.xy * clamp_rect.zw;
1151				//		splane.xy = clamp(splane.xy,clamp_rect.xy + scene_data_block.data.shadow_atlas_pixel_size,clamp_rect.xy + clamp_rect.zw - scene_data_block.data.shadow_atlas_pixel_size );
1152				splane.w = 1.0; //needed? i think it should be 1 already
1153		
1154				float shadow_z = textureLod(sampler2D(shadow_atlas, SAMPLER_LINEAR_CLAMP), splane.xy, 0.0).r;
1155				transmittance_z = (splane.z - shadow_z) / omni_lights.data[idx].inv_radius;
1156			}
1157		#endif
1158		
1159			if (sc_use_light_projector && omni_lights.data[idx].projector_rect != vec4(0.0)) {
1160				vec3 local_v = (omni_lights.data[idx].shadow_matrix * vec4(vertex, 1.0)).xyz;
1161				local_v = normalize(local_v);
1162		
1163				vec4 atlas_rect = omni_lights.data[idx].projector_rect;
1164		
1165				if (local_v.z >= 0.0) {
1166					atlas_rect.y += atlas_rect.w;
1167				}
1168		
1169				local_v.z = 1.0 + abs(local_v.z);
1170		
1171				local_v.xy /= local_v.z;
1172				local_v.xy = local_v.xy * 0.5 + 0.5;
1173				vec2 proj_uv = local_v.xy * atlas_rect.zw;
1174		
1175				if (sc_projector_use_mipmaps) {
1176					vec2 proj_uv_ddx;
1177					vec2 proj_uv_ddy;
1178					{
1179						vec3 local_v_ddx = (omni_lights.data[idx].shadow_matrix * vec4(vertex + vertex_ddx, 1.0)).xyz;
1180						local_v_ddx = normalize(local_v_ddx);
1181		
1182						if (local_v_ddx.z >= 0.0) {
1183							local_v_ddx.z += 1.0;
1184						} else {
1185							local_v_ddx.z = 1.0 - local_v_ddx.z;
1186						}
1187		
1188						local_v_ddx.xy /= local_v_ddx.z;
1189						local_v_ddx.xy = local_v_ddx.xy * 0.5 + 0.5;
1190		
1191						proj_uv_ddx = local_v_ddx.xy * atlas_rect.zw - proj_uv;
1192		
1193						vec3 local_v_ddy = (omni_lights.data[idx].shadow_matrix * vec4(vertex + vertex_ddy, 1.0)).xyz;
1194						local_v_ddy = normalize(local_v_ddy);
1195		
1196						if (local_v_ddy.z >= 0.0) {
1197							local_v_ddy.z += 1.0;
1198						} else {
1199							local_v_ddy.z = 1.0 - local_v_ddy.z;
1200						}
1201		
1202						local_v_ddy.xy /= local_v_ddy.z;
1203						local_v_ddy.xy = local_v_ddy.xy * 0.5 + 0.5;
1204		
1205						proj_uv_ddy = local_v_ddy.xy * atlas_rect.zw - proj_uv;
1206					}
1207		
1208					vec4 proj = textureGrad(sampler2D(decal_atlas_srgb, light_projector_sampler), proj_uv + atlas_rect.xy, proj_uv_ddx, proj_uv_ddy);
1209					color *= proj.rgb * proj.a;
1210				} else {
1211					vec4 proj = textureLod(sampler2D(decal_atlas_srgb, light_projector_sampler), proj_uv + atlas_rect.xy, 0.0);
1212					color *= proj.rgb * proj.a;
1213				}
1214			}
1215		
1216			light_attenuation *= shadow;
1217		
1218			light_compute(normal, normalize(light_rel_vec), eye_vec, size_A, color, false, light_attenuation, f0, orms, omni_lights.data[idx].specular_amount, albedo, alpha,
1219		#ifdef LIGHT_BACKLIGHT_USED
1220					backlight,
1221		#endif
1222		#ifdef LIGHT_TRANSMITTANCE_USED
1223					transmittance_color,
1224					transmittance_depth,
1225					transmittance_boost,
1226					transmittance_z,
1227		#endif
1228		#ifdef LIGHT_RIM_USED
1229					rim * omni_attenuation, rim_tint,
1230		#endif
1231		#ifdef LIGHT_CLEARCOAT_USED
1232					clearcoat, clearcoat_roughness, vertex_normal,
1233		#endif
1234		#ifdef LIGHT_ANISOTROPY_USED
1235					binormal, tangent, anisotropy,
1236		#endif
1237					diffuse_light,
1238					specular_light);
1239		}
1240		
1241		float light_process_spot_shadow(uint idx, vec3 vertex, vec3 normal) {
1242		#ifndef SHADOWS_DISABLED
1243			if (spot_lights.data[idx].shadow_opacity > 0.001) {
1244				vec3 light_rel_vec = spot_lights.data[idx].position - vertex;
1245				float light_length = length(light_rel_vec);
1246				vec3 spot_dir = spot_lights.data[idx].direction;
1247		
1248				vec3 shadow_dir = light_rel_vec / light_length;
1249				vec3 normal_bias = normal * light_length * spot_lights.data[idx].shadow_normal_bias * (1.0 - abs(dot(normal, shadow_dir)));
1250		
1251				//there is a shadowmap
1252				vec4 v = vec4(vertex + normal_bias, 1.0);
1253		
1254				vec4 splane = (spot_lights.data[idx].shadow_matrix * v);
1255				splane.z -= spot_lights.data[idx].shadow_bias / (light_length * spot_lights.data[idx].inv_radius);
1256				splane /= splane.w;
1257		
1258				float shadow;
1259				if (sc_use_light_soft_shadows && spot_lights.data[idx].soft_shadow_size > 0.0) {
1260					//soft shadow
1261		
1262					//find blocker
1263					float z_norm = dot(spot_dir, -light_rel_vec) * spot_lights.data[idx].inv_radius;
1264		
1265					vec2 shadow_uv = splane.xy * spot_lights.data[idx].atlas_rect.zw + spot_lights.data[idx].atlas_rect.xy;
1266		
1267					float blocker_count = 0.0;
1268					float blocker_average = 0.0;
1269		
1270					mat2 disk_rotation;
1271					{
1272						float r = quick_hash(gl_FragCoord.xy) * 2.0 * M_PI;
1273						float sr = sin(r);
1274						float cr = cos(r);
1275						disk_rotation = mat2(vec2(cr, -sr), vec2(sr, cr));
1276					}
1277		
1278					float uv_size = spot_lights.data[idx].soft_shadow_size * z_norm * spot_lights.data[idx].soft_shadow_scale;
1279					vec2 clamp_max = spot_lights.data[idx].atlas_rect.xy + spot_lights.data[idx].atlas_rect.zw;
1280					for (uint i = 0; i < sc_penumbra_shadow_samples; i++) {
1281						vec2 suv = shadow_uv + (disk_rotation * scene_data_block.data.penumbra_shadow_kernel[i].xy) * uv_size;
1282						suv = clamp(suv, spot_lights.data[idx].atlas_rect.xy, clamp_max);
1283						float d = textureLod(sampler2D(shadow_atlas, SAMPLER_LINEAR_CLAMP), suv, 0.0).r;
1284						if (d < splane.z) {
1285							blocker_average += d;
1286							blocker_count += 1.0;
1287						}
1288					}
1289		
1290					if (blocker_count > 0.0) {
1291						//blockers found, do soft shadow
1292						blocker_average /= blocker_count;
1293						float penumbra = (z_norm - blocker_average) / blocker_average;
1294						uv_size *= penumbra;
1295		
1296						shadow = 0.0;
1297						for (uint i = 0; i < sc_penumbra_shadow_samples; i++) {
1298							vec2 suv = shadow_uv + (disk_rotation * scene_data_block.data.penumbra_shadow_kernel[i].xy) * uv_size;
1299							suv = clamp(suv, spot_lights.data[idx].atlas_rect.xy, clamp_max);
1300							shadow += textureProj(sampler2DShadow(shadow_atlas, shadow_sampler), vec4(suv, splane.z, 1.0));
1301						}
1302		
1303						shadow /= float(sc_penumbra_shadow_samples);
1304						shadow = mix(1.0, shadow, spot_lights.data[idx].shadow_opacity);
1305		
1306					} else {
1307						//no blockers found, so no shadow
1308						shadow = 1.0;
1309					}
1310				} else {
1311					//hard shadow
1312					vec3 shadow_uv = vec3(splane.xy * spot_lights.data[idx].atlas_rect.zw + spot_lights.data[idx].atlas_rect.xy, splane.z);
1313					shadow = mix(1.0, sample_pcf_shadow(shadow_atlas, spot_lights.data[idx].soft_shadow_scale * scene_data_block.data.shadow_atlas_pixel_size, shadow_uv), spot_lights.data[idx].shadow_opacity);
1314				}
1315		
1316				return shadow;
1317			}
1318		
1319		#endif // SHADOWS_DISABLED
1320		
1321			return 1.0;
1322		}
1323		
1324		vec2 normal_to_panorama(vec3 n) {
1325			n = normalize(n);
1326			vec2 panorama_coords = vec2(atan(n.x, n.z), acos(-n.y));
1327		
1328			if (panorama_coords.x < 0.0) {
1329				panorama_coords.x += M_PI * 2.0;
1330			}
1331		
1332			panorama_coords /= vec2(M_PI * 2.0, M_PI);
1333			return panorama_coords;
1334		}
1335		
1336		void light_process_spot(uint idx, vec3 vertex, vec3 eye_vec, vec3 normal, vec3 vertex_ddx, vec3 vertex_ddy, vec3 f0, uint orms, float shadow, vec3 albedo, inout float alpha,
1337		#ifdef LIGHT_BACKLIGHT_USED
1338				vec3 backlight,
1339		#endif
1340		#ifdef LIGHT_TRANSMITTANCE_USED
1341				vec4 transmittance_color,
1342				float transmittance_depth,
1343				float transmittance_boost,
1344		#endif
1345		#ifdef LIGHT_RIM_USED
1346				float rim, float rim_tint,
1347		#endif
1348		#ifdef LIGHT_CLEARCOAT_USED
1349				float clearcoat, float clearcoat_roughness, vec3 vertex_normal,
1350		#endif
1351		#ifdef LIGHT_ANISOTROPY_USED
1352				vec3 binormal, vec3 tangent, float anisotropy,
1353		#endif
1354				inout vec3 diffuse_light,
1355				inout vec3 specular_light) {
1356			vec3 light_rel_vec = spot_lights.data[idx].position - vertex;
1357			float light_length = length(light_rel_vec);
1358			float spot_attenuation = get_omni_attenuation(light_length, spot_lights.data[idx].inv_radius, spot_lights.data[idx].attenuation);
1359			vec3 spot_dir = spot_lights.data[idx].direction;
1360		
1361			// This conversion to a highp float is crucial to prevent light leaking
1362			// due to precision errors in the following calculations (cone angle is mediump).
1363			highp float cone_angle = spot_lights.data[idx].cone_angle;
1364			float scos = max(dot(-normalize(light_rel_vec), spot_dir), cone_angle);
1365			float spot_rim = max(0.0001, (1.0 - scos) / (1.0 - cone_angle));
1366		
1367			spot_attenuation *= 1.0 - pow(spot_rim, spot_lights.data[idx].cone_attenuation);
1368			float light_attenuation = spot_attenuation;
1369			vec3 color = spot_lights.data[idx].color;
1370			float specular_amount = spot_lights.data[idx].specular_amount;
1371		
1372			float size_A = 0.0;
1373		
1374			if (sc_use_light_soft_shadows && spot_lights.data[idx].size > 0.0) {
1375				float t = spot_lights.data[idx].size / max(0.001, light_length);
1376				size_A = max(0.0, 1.0 - 1 / sqrt(1 + t * t));
1377			}
1378		
1379		#ifdef LIGHT_TRANSMITTANCE_USED
1380			float transmittance_z = transmittance_depth;
1381			transmittance_color.a *= light_attenuation;
1382			{
1383				vec4 splane = (spot_lights.data[idx].shadow_matrix * vec4(vertex - normalize(normal_interp) * spot_lights.data[idx].transmittance_bias, 1.0));
1384				splane /= splane.w;
1385				splane.xy = splane.xy * spot_lights.data[idx].atlas_rect.zw + spot_lights.data[idx].atlas_rect.xy;
1386		
1387				float shadow_z = textureLod(sampler2D(shadow_atlas, SAMPLER_LINEAR_CLAMP), splane.xy, 0.0).r;
1388		
1389				shadow_z = shadow_z * 2.0 - 1.0;
1390				float z_far = 1.0 / spot_lights.data[idx].inv_radius;
1391				float z_near = 0.01;
1392				shadow_z = 2.0 * z_near * z_far / (z_far + z_near - shadow_z * (z_far - z_near));
1393		
1394				//distance to light plane
1395				float z = dot(spot_dir, -light_rel_vec);
1396				transmittance_z = z - shadow_z;
1397			}
1398		#endif //LIGHT_TRANSMITTANCE_USED
1399		
1400			if (sc_use_light_projector && spot_lights.data[idx].projector_rect != vec4(0.0)) {
1401				vec4 splane = (spot_lights.data[idx].shadow_matrix * vec4(vertex, 1.0));
1402				splane /= splane.w;
1403		
1404				vec2 proj_uv = splane.xy * spot_lights.data[idx].projector_rect.zw;
1405		
1406				if (sc_projector_use_mipmaps) {
1407					//ensure we have proper mipmaps
1408					vec4 splane_ddx = (spot_lights.data[idx].shadow_matrix * vec4(vertex + vertex_ddx, 1.0));
1409					splane_ddx /= splane_ddx.w;
1410					vec2 proj_uv_ddx = splane_ddx.xy * spot_lights.data[idx].projector_rect.zw - proj_uv;
1411		
1412					vec4 splane_ddy = (spot_lights.data[idx].shadow_matrix * vec4(vertex + vertex_ddy, 1.0));
1413					splane_ddy /= splane_ddy.w;
1414					vec2 proj_uv_ddy = splane_ddy.xy * spot_lights.data[idx].projector_rect.zw - proj_uv;
1415		
1416					vec4 proj = textureGrad(sampler2D(decal_atlas_srgb, light_projector_sampler), proj_uv + spot_lights.data[idx].projector_rect.xy, proj_uv_ddx, proj_uv_ddy);
1417					color *= proj.rgb * proj.a;
1418				} else {
1419					vec4 proj = textureLod(sampler2D(decal_atlas_srgb, light_projector_sampler), proj_uv + spot_lights.data[idx].projector_rect.xy, 0.0);
1420					color *= proj.rgb * proj.a;
1421				}
1422			}
1423			light_attenuation *= shadow;
1424		
1425			light_compute(normal, normalize(light_rel_vec), eye_vec, size_A, color, false, light_attenuation, f0, orms, spot_lights.data[idx].specular_amount, albedo, alpha,
1426		#ifdef LIGHT_BACKLIGHT_USED
1427					backlight,
1428		#endif
1429		#ifdef LIGHT_TRANSMITTANCE_USED
1430					transmittance_color,
1431					transmittance_depth,
1432					transmittance_boost,
1433					transmittance_z,
1434		#endif
1435		#ifdef LIGHT_RIM_USED
1436					rim * spot_attenuation, rim_tint,
1437		#endif
1438		#ifdef LIGHT_CLEARCOAT_USED
1439					clearcoat, clearcoat_roughness, vertex_normal,
1440		#endif
1441		#ifdef LIGHT_ANISOTROPY_USED
1442					binormal, tangent, anisotropy,
1443		#endif
1444					diffuse_light, specular_light);
1445		}
1446		
1447		void reflection_process(uint ref_index, vec3 vertex, vec3 ref_vec, vec3 normal, float roughness, vec3 ambient_light, vec3 specular_light, inout vec4 ambient_accum, inout vec4 reflection_accum) {
1448			vec3 box_extents = reflections.data[ref_index].box_extents;
1449			vec3 local_pos = (reflections.data[ref_index].local_matrix * vec4(vertex, 1.0)).xyz;
1450		
1451			if (any(greaterThan(abs(local_pos), box_extents))) { //out of the reflection box
1452				return;
1453			}
1454		
1455			vec3 inner_pos = abs(local_pos / box_extents);
1456			float blend = max(inner_pos.x, max(inner_pos.y, inner_pos.z));
1457			//make blend more rounded
1458			blend = mix(length(inner_pos), blend, blend);
1459			blend *= blend;
1460			blend = max(0.0, 1.0 - blend);
1461		
1462			if (reflections.data[ref_index].intensity > 0.0) { // compute reflection
1463		
1464				vec3 local_ref_vec = (reflections.data[ref_index].local_matrix * vec4(ref_vec, 0.0)).xyz;
1465		
1466				if (reflections.data[ref_index].box_project) { //box project
1467		
1468					vec3 nrdir = normalize(local_ref_vec);
1469					vec3 rbmax = (box_extents - local_pos) / nrdir;
1470					vec3 rbmin = (-box_extents - local_pos) / nrdir;
1471		
1472					vec3 rbminmax = mix(rbmin, rbmax, greaterThan(nrdir, vec3(0.0, 0.0, 0.0)));
1473		
1474					float fa = min(min(rbminmax.x, rbminmax.y), rbminmax.z);
1475					vec3 posonbox = local_pos + nrdir * fa;
1476					local_ref_vec = posonbox - reflections.data[ref_index].box_offset;
1477				}
1478		
1479				vec4 reflection;
1480		
1481				reflection.rgb = textureLod(samplerCubeArray(reflection_atlas, SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP), vec4(local_ref_vec, reflections.data[ref_index].index), roughness * MAX_ROUGHNESS_LOD).rgb * sc_luminance_multiplier;
1482				reflection.rgb *= reflections.data[ref_index].exposure_normalization;
1483				if (reflections.data[ref_index].exterior) {
1484					reflection.rgb = mix(specular_light, reflection.rgb, blend);
1485				}
1486		
1487				reflection.rgb *= reflections.data[ref_index].intensity; //intensity
1488				reflection.a = blend;
1489				reflection.rgb *= reflection.a;
1490		
1491				reflection_accum += reflection;
1492			}
1493		
1494			switch (reflections.data[ref_index].ambient_mode) {
1495				case REFLECTION_AMBIENT_DISABLED: {
1496					//do nothing
1497				} break;
1498				case REFLECTION_AMBIENT_ENVIRONMENT: {
1499					//do nothing
1500					vec3 local_amb_vec = (reflections.data[ref_index].local_matrix * vec4(normal, 0.0)).xyz;
1501		
1502					vec4 ambient_out;
1503		
1504					ambient_out.rgb = textureLod(samplerCubeArray(reflection_atlas, SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP), vec4(local_amb_vec, reflections.data[ref_index].index), MAX_ROUGHNESS_LOD).rgb;
1505					ambient_out.rgb *= reflections.data[ref_index].exposure_normalization;
1506					ambient_out.a = blend;
1507					if (reflections.data[ref_index].exterior) {
1508						ambient_out.rgb = mix(ambient_light, ambient_out.rgb, blend);
1509					}
1510		
1511					ambient_out.rgb *= ambient_out.a;
1512					ambient_accum += ambient_out;
1513				} break;
1514				case REFLECTION_AMBIENT_COLOR: {
1515					vec4 ambient_out;
1516					ambient_out.a = blend;
1517					ambient_out.rgb = reflections.data[ref_index].ambient;
1518					if (reflections.data[ref_index].exterior) {
1519						ambient_out.rgb = mix(ambient_light, ambient_out.rgb, blend);
1520					}
1521					ambient_out.rgb *= ambient_out.a;
1522					ambient_accum += ambient_out;
1523				} break;
1524			}
1525		}
1526		
1527		float blur_shadow(float shadow) {
1528			return shadow;
1529		#if 0
1530			//disabling for now, will investigate later
1531			float interp_shadow = shadow;
1532			if (gl_HelperInvocation) {
1533				interp_shadow = -4.0; // technically anything below -4 will do but just to make sure
1534			}
1535		
1536			uvec2 fc2 = uvec2(gl_FragCoord.xy);
1537			interp_shadow -= dFdx(interp_shadow) * (float(fc2.x & 1) - 0.5);
1538			interp_shadow -= dFdy(interp_shadow) * (float(fc2.y & 1) - 0.5);
1539		
1540			if (interp_shadow >= 0.0) {
1541				shadow = interp_shadow;
1542			}
1543			return shadow;
1544		#endif
1545		}
1546		
1547		
1548		
1549		// Functions related to gi/sdfgi for our forward renderer
1550		
1551		//standard voxel cone trace
1552		vec4 voxel_cone_trace(texture3D probe, vec3 cell_size, vec3 pos, vec3 direction, float tan_half_angle, float max_distance, float p_bias) {
1553			float dist = p_bias;
1554			vec4 color = vec4(0.0);
1555		
1556			while (dist < max_distance && color.a < 0.95) {
1557				float diameter = max(1.0, 2.0 * tan_half_angle * dist);
1558				vec3 uvw_pos = (pos + dist * direction) * cell_size;
1559				float half_diameter = diameter * 0.5;
1560				//check if outside, then break
1561				if (any(greaterThan(abs(uvw_pos - 0.5), vec3(0.5f + half_diameter * cell_size)))) {
1562					break;
1563				}
1564				vec4 scolor = textureLod(sampler3D(probe, SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP), uvw_pos, log2(diameter));
1565				float a = (1.0 - color.a);
1566				color += a * scolor;
1567				dist += half_diameter;
1568			}
1569		
1570			return color;
1571		}
1572		
1573		vec4 voxel_cone_trace_45_degrees(texture3D probe, vec3 cell_size, vec3 pos, vec3 direction, float tan_half_angle, float max_distance, float p_bias) {
1574			float dist = p_bias;
1575			vec4 color = vec4(0.0);
1576			float radius = max(0.5, tan_half_angle * dist);
1577			float lod_level = log2(radius * 2.0);
1578		
1579			while (dist < max_distance && color.a < 0.95) {
1580				vec3 uvw_pos = (pos + dist * direction) * cell_size;
1581		
1582				//check if outside, then break
1583				if (any(greaterThan(abs(uvw_pos - 0.5), vec3(0.5f + radius * cell_size)))) {
1584					break;
1585				}
1586				vec4 scolor = textureLod(sampler3D(probe, SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP), uvw_pos, lod_level);
1587				lod_level += 1.0;
1588		
1589				float a = (1.0 - color.a);
1590				scolor *= a;
1591				color += scolor;
1592				dist += radius;
1593				radius = max(0.5, tan_half_angle * dist);
1594			}
1595		
1596			return color;
1597		}
1598		
1599		void voxel_gi_compute(uint index, vec3 position, vec3 normal, vec3 ref_vec, mat3 normal_xform, float roughness, vec3 ambient, vec3 environment, inout vec4 out_spec, inout vec4 out_diff) {
1600			position = (voxel_gi_instances.data[index].xform * vec4(position, 1.0)).xyz;
1601			ref_vec = normalize((voxel_gi_instances.data[index].xform * vec4(ref_vec, 0.0)).xyz);
1602			normal = normalize((voxel_gi_instances.data[index].xform * vec4(normal, 0.0)).xyz);
1603		
1604			position += normal * voxel_gi_instances.data[index].normal_bias;
1605		
1606			//this causes corrupted pixels, i have no idea why..
1607			if (any(bvec2(any(lessThan(position, vec3(0.0))), any(greaterThan(position, voxel_gi_instances.data[index].bounds))))) {
1608				return;
1609			}
1610		
1611			vec3 blendv = abs(position / voxel_gi_instances.data[index].bounds * 2.0 - 1.0);
1612			float blend = clamp(1.0 - max(blendv.x, max(blendv.y, blendv.z)), 0.0, 1.0);
1613			//float blend=1.0;
1614		
1615			float max_distance = length(voxel_gi_instances.data[index].bounds);
1616			vec3 cell_size = 1.0 / voxel_gi_instances.data[index].bounds;
1617		
1618			//radiance
1619		
1620		#define MAX_CONE_DIRS 4
1621		
1622			vec3 cone_dirs[MAX_CONE_DIRS] = vec3[](
1623					vec3(0.707107, 0.0, 0.707107),
1624					vec3(0.0, 0.707107, 0.707107),
1625					vec3(-0.707107, 0.0, 0.707107),
1626					vec3(0.0, -0.707107, 0.707107));
1627		
1628			float cone_weights[MAX_CONE_DIRS] = float[](0.25, 0.25, 0.25, 0.25);
1629			float cone_angle_tan = 0.98269;
1630		
1631			vec3 light = vec3(0.0);
1632		
1633			for (int i = 0; i < MAX_CONE_DIRS; i++) {
1634				vec3 dir = normalize((voxel_gi_instances.data[index].xform * vec4(normal_xform * cone_dirs[i], 0.0)).xyz);
1635		
1636				vec4 cone_light = voxel_cone_trace_45_degrees(voxel_gi_textures[index], cell_size, position, dir, cone_angle_tan, max_distance, voxel_gi_instances.data[index].bias);
1637		
1638				if (voxel_gi_instances.data[index].blend_ambient) {
1639					cone_light.rgb = mix(ambient, cone_light.rgb, min(1.0, cone_light.a / 0.95));
1640				}
1641		
1642				light += cone_weights[i] * cone_light.rgb;
1643			}
1644		
1645			light *= voxel_gi_instances.data[index].dynamic_range * voxel_gi_instances.data[index].exposure_normalization;
1646			out_diff += vec4(light * blend, blend);
1647		
1648			//irradiance
1649			vec4 irr_light = voxel_cone_trace(voxel_gi_textures[index], cell_size, position, ref_vec, tan(roughness * 0.5 * M_PI * 0.99), max_distance, voxel_gi_instances.data[index].bias);
1650			if (voxel_gi_instances.data[index].blend_ambient) {
1651				irr_light.rgb = mix(environment, irr_light.rgb, min(1.0, irr_light.a / 0.95));
1652			}
1653			irr_light.rgb *= voxel_gi_instances.data[index].dynamic_range * voxel_gi_instances.data[index].exposure_normalization;
1654			//irr_light=vec3(0.0);
1655		
1656			out_spec += vec4(irr_light.rgb * blend, blend);
1657		}
1658		
1659		vec2 octahedron_wrap(vec2 v) {
1660			vec2 signVal;
1661			signVal.x = v.x >= 0.0 ? 1.0 : -1.0;
1662			signVal.y = v.y >= 0.0 ? 1.0 : -1.0;
1663			return (1.0 - abs(v.yx)) * signVal;
1664		}
1665		
1666		vec2 octahedron_encode(vec3 n) {
1667			// https://twitter.com/Stubbesaurus/status/937994790553227264
1668			n /= (abs(n.x) + abs(n.y) + abs(n.z));
1669			n.xy = n.z >= 0.0 ? n.xy : octahedron_wrap(n.xy);
1670			n.xy = n.xy * 0.5 + 0.5;
1671			return n.xy;
1672		}
1673		
1674		void sdfgi_process(uint cascade, vec3 cascade_pos, vec3 cam_pos, vec3 cam_normal, vec3 cam_specular_normal, bool use_specular, float roughness, out vec3 diffuse_light, out vec3 specular_light, out float blend) {
1675			cascade_pos += cam_normal * sdfgi.normal_bias;
1676		
1677			vec3 base_pos = floor(cascade_pos);
1678			//cascade_pos += mix(vec3(0.0),vec3(0.01),lessThan(abs(cascade_pos-base_pos),vec3(0.01))) * cam_normal;
1679			ivec3 probe_base_pos = ivec3(base_pos);
1680		
1681			vec4 diffuse_accum = vec4(0.0);
1682			vec3 specular_accum;
1683		
1684			ivec3 tex_pos = ivec3(probe_base_pos.xy, int(cascade));
1685			tex_pos.x += probe_base_pos.z * sdfgi.probe_axis_size;
1686			tex_pos.xy = tex_pos.xy * (SDFGI_OCT_SIZE + 2) + ivec2(1);
1687		
1688			vec3 diffuse_posf = (vec3(tex_pos) + vec3(octahedron_encode(cam_normal) * float(SDFGI_OCT_SIZE), 0.0)) * sdfgi.lightprobe_tex_pixel_size;
1689		
1690			vec3 specular_posf;
1691		
1692			if (use_specular) {
1693				specular_accum = vec3(0.0);
1694				specular_posf = (vec3(tex_pos) + vec3(octahedron_encode(cam_specular_normal) * float(SDFGI_OCT_SIZE), 0.0)) * sdfgi.lightprobe_tex_pixel_size;
1695			}
1696		
1697			vec4 light_accum = vec4(0.0);
1698			float weight_accum = 0.0;
1699		
1700			for (uint j = 0; j < 8; j++) {
1701				ivec3 offset = (ivec3(j) >> ivec3(0, 1, 2)) & ivec3(1, 1, 1);
1702				ivec3 probe_posi = probe_base_pos;
1703				probe_posi += offset;
1704		
1705				// Compute weight
1706		
1707				vec3 probe_pos = vec3(probe_posi);
1708				vec3 probe_to_pos = cascade_pos - probe_pos;
1709				vec3 probe_dir = normalize(-probe_to_pos);
1710		
1711				vec3 trilinear = vec3(1.0) - abs(probe_to_pos);
1712				float weight = trilinear.x * trilinear.y * trilinear.z * max(0.005, dot(cam_normal, probe_dir));
1713		
1714				// Compute lightprobe occlusion
1715		
1716				if (sdfgi.use_occlusion) {
1717					ivec3 occ_indexv = abs((sdfgi.cascades[cascade].probe_world_offset + probe_posi) & ivec3(1, 1, 1)) * ivec3(1, 2, 4);
1718					vec4 occ_mask = mix(vec4(0.0), vec4(1.0), equal(ivec4(occ_indexv.x | occ_indexv.y), ivec4(0, 1, 2, 3)));
1719		
1720					vec3 occ_pos = clamp(cascade_pos, probe_pos - sdfgi.occlusion_clamp, probe_pos + sdfgi.occlusion_clamp) * sdfgi.probe_to_uvw;
1721					occ_pos.z += float(cascade);
1722					if (occ_indexv.z != 0) { //z bit is on, means index is >=4, so make it switch to the other half of textures
1723						occ_pos.x += 1.0;
1724					}
1725		
1726					occ_pos *= sdfgi.occlusion_renormalize;
1727					float occlusion = dot(textureLod(sampler3D(sdfgi_occlusion_cascades, SAMPLER_LINEAR_CLAMP), occ_pos, 0.0), occ_mask);
1728		
1729					weight *= max(occlusion, 0.01);
1730				}
1731		
1732				// Compute lightprobe texture position
1733		
1734				vec3 diffuse;
1735				vec3 pos_uvw = diffuse_posf;
1736				pos_uvw.xy += vec2(offset.xy) * sdfgi.lightprobe_uv_offset.xy;
1737				pos_uvw.x += float(offset.z) * sdfgi.lightprobe_uv_offset.z;
1738				diffuse = textureLod(sampler2DArray(sdfgi_lightprobe_texture, SAMPLER_LINEAR_CLAMP), pos_uvw, 0.0).rgb;
1739		
1740				diffuse_accum += vec4(diffuse * weight * sdfgi.cascades[cascade].exposure_normalization, weight);
1741		
1742				if (use_specular) {
1743					vec3 specular = vec3(0.0);
1744					vec3 pos_uvw = specular_posf;
1745					pos_uvw.xy += vec2(offset.xy) * sdfgi.lightprobe_uv_offset.xy;
1746					pos_uvw.x += float(offset.z) * sdfgi.lightprobe_uv_offset.z;
1747					if (roughness < 0.99) {
1748						specular = textureLod(sampler2DArray(sdfgi_lightprobe_texture, SAMPLER_LINEAR_CLAMP), pos_uvw + vec3(0, 0, float(sdfgi.max_cascades)), 0.0).rgb;
1749					}
1750					if (roughness > 0.5) {
1751						specular = mix(specular, textureLod(sampler2DArray(sdfgi_lightprobe_texture, SAMPLER_LINEAR_CLAMP), pos_uvw, 0.0).rgb, (roughness - 0.5) * 2.0);
1752					}
1753		
1754					specular_accum += specular * weight * sdfgi.cascades[cascade].exposure_normalization;
1755				}
1756			}
1757		
1758			if (diffuse_accum.a > 0.0) {
1759				diffuse_accum.rgb /= diffuse_accum.a;
1760			}
1761		
1762			diffuse_light = diffuse_accum.rgb;
1763		
1764			if (use_specular) {
1765				if (diffuse_accum.a > 0.0) {
1766					specular_accum /= diffuse_accum.a;
1767				}
1768		
1769				specular_light = specular_accum;
1770			}
1771		
1772			{
1773				//process blend
1774				float blend_from = (float(sdfgi.probe_axis_size - 1) / 2.0) - 2.5;
1775				float blend_to = blend_from + 2.0;
1776		
1777				vec3 inner_pos = cam_pos * sdfgi.cascades[cascade].to_probe;
1778		
1779				float len = length(inner_pos);
1780		
1781				inner_pos = abs(normalize(inner_pos));
1782				len *= max(inner_pos.x, max(inner_pos.y, inner_pos.z));
1783		
1784				if (len >= blend_from) {
1785					blend = smoothstep(blend_from, blend_to, len);
1786				} else {
1787					blend = 0.0;
1788				}
1789			}
1790		}
1791		
1792		
1793		#endif //!defined(MODE_RENDER_DEPTH) && !defined(MODE_UNSHADED)
1794		
1795		#ifndef MODE_RENDER_DEPTH
1796		
1797		vec4 volumetric_fog_process(vec2 screen_uv, float z) {
1798			vec3 fog_pos = vec3(screen_uv, z * implementation_data.volumetric_fog_inv_length);
1799			if (fog_pos.z < 0.0) {
1800				return vec4(0.0);
1801			} else if (fog_pos.z < 1.0) {
1802				fog_pos.z = pow(fog_pos.z, implementation_data.volumetric_fog_detail_spread);
1803			}
1804		
1805			return texture(sampler3D(volumetric_fog_texture, SAMPLER_LINEAR_CLAMP), fog_pos);
1806		}
1807		
1808		vec4 fog_process(vec3 vertex) {
1809			vec3 fog_color = scene_data_block.data.fog_light_color;
1810		
1811			if (scene_data_block.data.fog_aerial_perspective > 0.0) {
1812				vec3 sky_fog_color = vec3(0.0);
1813				vec3 cube_view = scene_data_block.data.radiance_inverse_xform * vertex;
1814				// mip_level always reads from the second mipmap and higher so the fog is always slightly blurred
1815				float mip_level = mix(1.0 / MAX_ROUGHNESS_LOD, 1.0, 1.0 - (abs(vertex.z) - scene_data_block.data.z_near) / (scene_data_block.data.z_far - scene_data_block.data.z_near));
1816		#ifdef USE_RADIANCE_CUBEMAP_ARRAY
1817				float lod, blend;
1818				blend = modf(mip_level * MAX_ROUGHNESS_LOD, lod);
1819				sky_fog_color = texture(samplerCubeArray(radiance_cubemap, SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP), vec4(cube_view, lod)).rgb;
1820				sky_fog_color = mix(sky_fog_color, texture(samplerCubeArray(radiance_cubemap, SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP), vec4(cube_view, lod + 1)).rgb, blend);
1821		#else
1822				sky_fog_color = textureLod(samplerCube(radiance_cubemap, SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP), cube_view, mip_level * MAX_ROUGHNESS_LOD).rgb;
1823		#endif //USE_RADIANCE_CUBEMAP_ARRAY
1824				fog_color = mix(fog_color, sky_fog_color, scene_data_block.data.fog_aerial_perspective);
1825			}
1826		
1827			if (scene_data_block.data.fog_sun_scatter > 0.001) {
1828				vec4 sun_scatter = vec4(0.0);
1829				float sun_total = 0.0;
1830				vec3 view = normalize(vertex);
1831		
1832				for (uint i = 0; i < scene_data_block.data.directional_light_count; i++) {
1833					vec3 light_color = directional_lights.data[i].color * directional_lights.data[i].energy;
1834					float light_amount = pow(max(dot(view, directional_lights.data[i].direction), 0.0), 8.0);
1835					fog_color += light_color * light_amount * scene_data_block.data.fog_sun_scatter;
1836				}
1837			}
1838		
1839			float fog_amount = 1.0 - exp(min(0.0, -length(vertex) * scene_data_block.data.fog_density));
1840		
1841			if (abs(scene_data_block.data.fog_height_density) >= 0.0001) {
1842				float y = (scene_data_block.data.inv_view_matrix * vec4(vertex, 1.0)).y;
1843		
1844				float y_dist = y - scene_data_block.data.fog_height;
1845		
1846				float vfog_amount = 1.0 - exp(min(0.0, y_dist * scene_data_block.data.fog_height_density));
1847		
1848				fog_amount = max(vfog_amount, fog_amount);
1849			}
1850		
1851			return vec4(fog_color, fog_amount);
1852		}
1853		
1854		void cluster_get_item_range(uint p_offset, out uint item_min, out uint item_max, out uint item_from, out uint item_to) {
1855			uint item_min_max = cluster_buffer.data[p_offset];
1856			item_min = item_min_max & 0xFFFFu;
1857			item_max = item_min_max >> 16;
1858		
1859			item_from = item_min >> 5;
1860			item_to = (item_max == 0) ? 0 : ((item_max - 1) >> 5) + 1; //side effect of how it is stored, as item_max 0 means no elements
1861		}
1862		
1863		uint cluster_get_range_clip_mask(uint i, uint z_min, uint z_max) {
1864			int local_min = clamp(int(z_min) - int(i) * 32, 0, 31);
1865			int mask_width = min(int(z_max) - int(z_min), 32 - local_min);
1866			return bitfieldInsert(uint(0), uint(0xFFFFFFFF), local_min, mask_width);
1867		}
1868		
1869		#endif //!MODE_RENDER DEPTH
1870		
1871		void fragment_shader(in SceneData scene_data) {
1872			uint instance_index = instance_index_interp;
1873		
1874			//lay out everything, whatever is unused is optimized away anyway
1875			vec3 vertex = vertex_interp;
1876		#ifdef USE_MULTIVIEW
1877			vec3 eye_offset = scene_data.eye_offset[ViewIndex].xyz;
1878			vec3 view = -normalize(vertex_interp - eye_offset);
1879		
1880			// UV in our combined frustum space is used for certain screen uv processes where it's
1881			// overkill to render separate left and right eye views
1882			vec2 combined_uv = (combined_projected.xy / combined_projected.w) * 0.5 + 0.5;
1883		#else
1884			vec3 eye_offset = vec3(0.0, 0.0, 0.0);
1885			vec3 view = -normalize(vertex_interp);
1886		#endif
1887			vec3 albedo = vec3(1.0);
1888			vec3 backlight = vec3(0.0);
1889			vec4 transmittance_color = vec4(0.0, 0.0, 0.0, 1.0);
1890			float transmittance_depth = 0.0;
1891			float transmittance_boost = 0.0;
1892			float metallic = 0.0;
1893			float specular = 0.5;
1894			vec3 emission = vec3(0.0);
1895			float roughness = 1.0;
1896			float rim = 0.0;
1897			float rim_tint = 0.0;
1898			float clearcoat = 0.0;
1899			float clearcoat_roughness = 0.0;
1900			float anisotropy = 0.0;
1901			vec2 anisotropy_flow = vec2(1.0, 0.0);
1902		#ifndef FOG_DISABLED
1903			vec4 fog = vec4(0.0);
1904		#endif // !FOG_DISABLED
1905		#if defined(CUSTOM_RADIANCE_USED)
1906			vec4 custom_radiance = vec4(0.0);
1907		#endif
1908		#if defined(CUSTOM_IRRADIANCE_USED)
1909			vec4 custom_irradiance = vec4(0.0);
1910		#endif
1911		
1912			float ao = 1.0;
1913			float ao_light_affect = 0.0;
1914		
1915			float alpha = float(instances.data[instance_index].flags >> INSTANCE_FLAGS_FADE_SHIFT) / float(255.0);
1916		
1917		#ifdef TANGENT_USED
1918			vec3 binormal = normalize(binormal_interp);
1919			vec3 tangent = normalize(tangent_interp);
1920		#else
1921			vec3 binormal = vec3(0.0);
1922			vec3 tangent = vec3(0.0);
1923		#endif
1924		
1925		#ifdef NORMAL_USED
1926			vec3 normal = normalize(normal_interp);
1927		
1928		#if defined(DO_SIDE_CHECK)
1929			if (!gl_FrontFacing) {
1930				normal = -normal;
1931			}
1932		#endif
1933		
1934		#endif //NORMAL_USED
1935		
1936		#ifdef UV_USED
1937			vec2 uv = uv_interp;
1938		#endif
1939		
1940		#if defined(UV2_USED) || defined(USE_LIGHTMAP)
1941			vec2 uv2 = uv2_interp;
1942		#endif
1943		
1944		#if defined(COLOR_USED)
1945			vec4 color = color_interp;
1946		#endif
1947		
1948		#if defined(NORMAL_MAP_USED)
1949		
1950			vec3 normal_map = vec3(0.5);
1951		#endif
1952		
1953			float normal_map_depth = 1.0;
1954		
1955			vec2 screen_uv = gl_FragCoord.xy * scene_data.screen_pixel_size;
1956		
1957			float sss_strength = 0.0;
1958		
1959		#ifdef ALPHA_SCISSOR_USED
1960			float alpha_scissor_threshold = 1.0;
1961		#endif // ALPHA_SCISSOR_USED
1962		
1963		#ifdef ALPHA_HASH_USED
1964			float alpha_hash_scale = 1.0;
1965		#endif // ALPHA_HASH_USED
1966		
1967		#ifdef ALPHA_ANTIALIASING_EDGE_USED
1968			float alpha_antialiasing_edge = 0.0;
1969			vec2 alpha_texture_coordinate = vec2(0.0, 0.0);
1970		#endif // ALPHA_ANTIALIASING_EDGE_USED
1971		
1972			mat4 inv_view_matrix = scene_data.inv_view_matrix;
1973			mat4 read_model_matrix = instances.data[instance_index].transform;
1974		#ifdef USE_DOUBLE_PRECISION
1975			read_model_matrix[0][3] = 0.0;
1976			read_model_matrix[1][3] = 0.0;
1977			read_model_matrix[2][3] = 0.0;
1978			inv_view_matrix[0][3] = 0.0;
1979			inv_view_matrix[1][3] = 0.0;
1980			inv_view_matrix[2][3] = 0.0;
1981		#endif
1982			mat4 read_view_matrix = scene_data.view_matrix;
1983			vec2 read_viewport_size = scene_data.viewport_size;
1984			{
1985		#CODE : FRAGMENT
1986			}
1987		
1988		#ifdef LIGHT_TRANSMITTANCE_USED
1989			transmittance_color.a *= sss_strength;
1990		#endif
1991		
1992		#ifndef USE_SHADOW_TO_OPACITY
1993		
1994		#ifdef ALPHA_SCISSOR_USED
1995			if (alpha < alpha_scissor_threshold) {
1996				discard;
1997			}
1998		#endif // ALPHA_SCISSOR_USED
1999		
2000		// alpha hash can be used in unison with alpha antialiasing
2001		#ifdef ALPHA_HASH_USED
2002			vec3 object_pos = (inverse(read_model_matrix) * inv_view_matrix * vec4(vertex, 1.0)).xyz;
2003			if (alpha < compute_alpha_hash_threshold(object_pos, alpha_hash_scale)) {
2004				discard;
2005			}
2006		#endif // ALPHA_HASH_USED
2007		
2008		// If we are not edge antialiasing, we need to remove the output alpha channel from scissor and hash
2009		#if (defined(ALPHA_SCISSOR_USED) || defined(ALPHA_HASH_USED)) && !defined(ALPHA_ANTIALIASING_EDGE_USED)
2010			alpha = 1.0;
2011		#endif
2012		
2013		#ifdef ALPHA_ANTIALIASING_EDGE_USED
2014		// If alpha scissor is used, we must further the edge threshold, otherwise we won't get any edge feather
2015		#ifdef ALPHA_SCISSOR_USED
2016			alpha_antialiasing_edge = clamp(alpha_scissor_threshold + alpha_antialiasing_edge, 0.0, 1.0);
2017		#endif
2018			alpha = compute_alpha_antialiasing_edge(alpha, alpha_texture_coordinate, alpha_antialiasing_edge);
2019		#endif // ALPHA_ANTIALIASING_EDGE_USED
2020		
2021		#ifdef MODE_RENDER_DEPTH
2022		#if defined(USE_OPAQUE_PREPASS) || defined(ALPHA_ANTIALIASING_EDGE_USED)
2023			if (alpha < scene_data.opaque_prepass_threshold) {
2024				discard;
2025			}
2026		#endif // USE_OPAQUE_PREPASS || ALPHA_ANTIALIASING_EDGE_USED
2027		#endif // MODE_RENDER_DEPTH
2028		
2029		#endif // !USE_SHADOW_TO_OPACITY
2030		
2031		#ifdef NORMAL_MAP_USED
2032		
2033			normal_map.xy = normal_map.xy * 2.0 - 1.0;
2034			normal_map.z = sqrt(max(0.0, 1.0 - dot(normal_map.xy, normal_map.xy))); //always ignore Z, as it can be RG packed, Z may be pos/neg, etc.
2035		
2036			normal = normalize(mix(normal, tangent * normal_map.x + binormal * normal_map.y + normal * normal_map.z, normal_map_depth));
2037		
2038		#endif
2039		
2040		#ifdef LIGHT_ANISOTROPY_USED
2041		
2042			if (anisotropy > 0.01) {
2043				//rotation matrix
2044				mat3 rot = mat3(tangent, binormal, normal);
2045				//make local to space
2046				tangent = normalize(rot * vec3(anisotropy_flow.x, anisotropy_flow.y, 0.0));
2047				binormal = normalize(rot * vec3(-anisotropy_flow.y, anisotropy_flow.x, 0.0));
2048			}
2049		
2050		#endif
2051		
2052		#ifdef ENABLE_CLIP_ALPHA
2053			if (albedo.a < 0.99) {
2054				//used for doublepass and shadowmapping
2055				discard;
2056			}
2057		#endif
2058		
2059			/////////////////////// FOG //////////////////////
2060		#ifndef MODE_RENDER_DEPTH
2061		
2062		#ifndef FOG_DISABLED
2063		#ifndef CUSTOM_FOG_USED
2064			// fog must be processed as early as possible and then packed.
2065			// to maximize VGPR usage
2066			// Draw "fixed" fog before volumetric fog to ensure volumetric fog can appear in front of the sky.
2067		
2068			if (scene_data.fog_enabled) {
2069				fog = fog_process(vertex);
2070			}
2071		
2072			if (implementation_data.volumetric_fog_enabled) {
2073		#ifdef USE_MULTIVIEW
2074				vec4 volumetric_fog = volumetric_fog_process(combined_uv, -vertex.z);
2075		#else
2076				vec4 volumetric_fog = volumetric_fog_process(screen_uv, -vertex.z);
2077		#endif
2078				if (scene_data.fog_enabled) {
2079					//must use the full blending equation here to blend fogs
2080					vec4 res;
2081					float sa = 1.0 - volumetric_fog.a;
2082					res.a = fog.a * sa + volumetric_fog.a;
2083					if (res.a == 0.0) {
2084						res.rgb = vec3(0.0);
2085					} else {
2086						res.rgb = (fog.rgb * fog.a * sa + volumetric_fog.rgb * volumetric_fog.a) / res.a;
2087					}
2088					fog = res;
2089				} else {
2090					fog = volumetric_fog;
2091				}
2092			}
2093		#endif //!CUSTOM_FOG_USED
2094		
2095			uint fog_rg = packHalf2x16(fog.rg);
2096			uint fog_ba = packHalf2x16(fog.ba);
2097		
2098		#endif //!FOG_DISABLED
2099		#endif //!MODE_RENDER_DEPTH
2100		
2101			/////////////////////// DECALS ////////////////////////////////
2102		
2103		#ifndef MODE_RENDER_DEPTH
2104		
2105		#ifdef USE_MULTIVIEW
2106			uvec2 cluster_pos = uvec2(combined_uv.xy / scene_data.screen_pixel_size) >> implementation_data.cluster_shift;
2107		#else
2108			uvec2 cluster_pos = uvec2(gl_FragCoord.xy) >> implementation_data.cluster_shift;
2109		#endif
2110			uint cluster_offset = (implementation_data.cluster_width * cluster_pos.y + cluster_pos.x) * (implementation_data.max_cluster_element_count_div_32 + 32);
2111		
2112			uint cluster_z = uint(clamp((-vertex.z / scene_data.z_far) * 32.0, 0.0, 31.0));
2113		
2114			//used for interpolating anything cluster related
2115			vec3 vertex_ddx = dFdx(vertex);
2116			vec3 vertex_ddy = dFdy(vertex);
2117		
2118			{ // process decals
2119		
2120				uint cluster_decal_offset = cluster_offset + implementation_data.cluster_type_size * 2;
2121		
2122				uint item_min;
2123				uint item_max;
2124				uint item_from;
2125				uint item_to;
2126		
2127				cluster_get_item_range(cluster_decal_offset + implementation_data.max_cluster_element_count_div_32 + cluster_z, item_min, item_max, item_from, item_to);
2128		
2129		#ifdef USE_SUBGROUPS
2130				item_from = subgroupBroadcastFirst(subgroupMin(item_from));
2131				item_to = subgroupBroadcastFirst(subgroupMax(item_to));
2132		#endif
2133		
2134				for (uint i = item_from; i < item_to; i++) {
2135					uint mask = cluster_buffer.data[cluster_decal_offset + i];
2136					mask &= cluster_get_range_clip_mask(i, item_min, item_max);
2137		#ifdef USE_SUBGROUPS
2138					uint merged_mask = subgroupBroadcastFirst(subgroupOr(mask));
2139		#else
2140					uint merged_mask = mask;
2141		#endif
2142		
2143					while (merged_mask != 0) {
2144						uint bit = findMSB(merged_mask);
2145						merged_mask &= ~(1u << bit);
2146		#ifdef USE_SUBGROUPS
2147						if (((1u << bit) & mask) == 0) { //do not process if not originally here
2148							continue;
2149						}
2150		#endif
2151						uint decal_index = 32 * i + bit;
2152		
2153						if (!bool(decals.data[decal_index].mask & instances.data[instance_index].layer_mask)) {
2154							continue; //not masked
2155						}
2156		
2157						vec3 uv_local = (decals.data[decal_index].xform * vec4(vertex, 1.0)).xyz;
2158						if (any(lessThan(uv_local, vec3(0.0, -1.0, 0.0))) || any(greaterThan(uv_local, vec3(1.0)))) {
2159							continue; //out of decal
2160						}
2161		
2162						float fade = pow(1.0 - (uv_local.y > 0.0 ? uv_local.y : -uv_local.y), uv_local.y > 0.0 ? decals.data[decal_index].upper_fade : decals.data[decal_index].lower_fade);
2163		
2164						if (decals.data[decal_index].normal_fade > 0.0) {
2165							fade *= smoothstep(decals.data[decal_index].normal_fade, 1.0, dot(normal_interp, decals.data[decal_index].normal) * 0.5 + 0.5);
2166						}
2167		
2168						//we need ddx/ddy for mipmaps, so simulate them
2169						vec2 ddx = (decals.data[decal_index].xform * vec4(vertex_ddx, 0.0)).xz;
2170						vec2 ddy = (decals.data[decal_index].xform * vec4(vertex_ddy, 0.0)).xz;
2171		
2172						if (decals.data[decal_index].albedo_rect != vec4(0.0)) {
2173							//has albedo
2174							vec4 decal_albedo;
2175							if (sc_decal_use_mipmaps) {
2176								decal_albedo = textureGrad(sampler2D(decal_atlas_srgb, decal_sampler), uv_local.xz * decals.data[decal_index].albedo_rect.zw + decals.data[decal_index].albedo_rect.xy, ddx * decals.data[decal_index].albedo_rect.zw, ddy * decals.data[decal_index].albedo_rect.zw);
2177							} else {
2178								decal_albedo = textureLod(sampler2D(decal_atlas_srgb, decal_sampler), uv_local.xz * decals.data[decal_index].albedo_rect.zw + decals.data[decal_index].albedo_rect.xy, 0.0);
2179							}
2180							decal_albedo *= decals.data[decal_index].modulate;
2181							decal_albedo.a *= fade;
2182							albedo = mix(albedo, decal_albedo.rgb, decal_albedo.a * decals.data[decal_index].albedo_mix);
2183		
2184							if (decals.data[decal_index].normal_rect != vec4(0.0)) {
2185								vec3 decal_normal;
2186								if (sc_decal_use_mipmaps) {
2187									decal_normal = textureGrad(sampler2D(decal_atlas, decal_sampler), uv_local.xz * decals.data[decal_index].normal_rect.zw + decals.data[decal_index].normal_rect.xy, ddx * decals.data[decal_index].normal_rect.zw, ddy * decals.data[decal_index].normal_rect.zw).xyz;
2188								} else {
2189									decal_normal = textureLod(sampler2D(decal_atlas, decal_sampler), uv_local.xz * decals.data[decal_index].normal_rect.zw + decals.data[decal_index].normal_rect.xy, 0.0).xyz;
2190								}
2191								decal_normal.xy = decal_normal.xy * vec2(2.0, -2.0) - vec2(1.0, -1.0); //users prefer flipped y normal maps in most authoring software
2192								decal_normal.z = sqrt(max(0.0, 1.0 - dot(decal_normal.xy, decal_normal.xy)));
2193								//convert to view space, use xzy because y is up
2194								decal_normal = (decals.data[decal_index].normal_xform * decal_normal.xzy).xyz;
2195		
2196								normal = normalize(mix(normal, decal_normal, decal_albedo.a));
2197							}
2198		
2199							if (decals.data[decal_index].orm_rect != vec4(0.0)) {
2200								vec3 decal_orm;
2201								if (sc_decal_use_mipmaps) {
2202									decal_orm = textureGrad(sampler2D(decal_atlas, decal_sampler), uv_local.xz * decals.data[decal_index].orm_rect.zw + decals.data[decal_index].orm_rect.xy, ddx * decals.data[decal_index].orm_rect.zw, ddy * decals.data[decal_index].orm_rect.zw).xyz;
2203								} else {
2204									decal_orm = textureLod(sampler2D(decal_atlas, decal_sampler), uv_local.xz * decals.data[decal_index].orm_rect.zw + decals.data[decal_index].orm_rect.xy, 0.0).xyz;
2205								}
2206								ao = mix(ao, decal_orm.r, decal_albedo.a);
2207								roughness = mix(roughness, decal_orm.g, decal_albedo.a);
2208								metallic = mix(metallic, decal_orm.b, decal_albedo.a);
2209							}
2210						}
2211		
2212						if (decals.data[decal_index].emission_rect != vec4(0.0)) {
2213							//emission is additive, so its independent from albedo
2214							if (sc_decal_use_mipmaps) {
2215								emission += textureGrad(sampler2D(decal_atlas_srgb, decal_sampler), uv_local.xz * decals.data[decal_index].emission_rect.zw + decals.data[decal_index].emission_rect.xy, ddx * decals.data[decal_index].emission_rect.zw, ddy * decals.data[decal_index].emission_rect.zw).xyz * decals.data[decal_index].modulate.rgb * decals.data[decal_index].emission_energy * fade;
2216							} else {
2217								emission += textureLod(sampler2D(decal_atlas_srgb, decal_sampler), uv_local.xz * decals.data[decal_index].emission_rect.zw + decals.data[decal_index].emission_rect.xy, 0.0).xyz * decals.data[decal_index].modulate.rgb * decals.data[decal_index].emission_energy * fade;
2218							}
2219						}
2220					}
2221				}
2222			}
2223		
2224			//pack albedo until needed again, saves 2 VGPRs in the meantime
2225		
2226		#endif //not render depth
2227			/////////////////////// LIGHTING //////////////////////////////
2228		
2229		#ifdef NORMAL_USED
2230			if (scene_data.roughness_limiter_enabled) {
2231				//https://www.jp.square-enix.com/tech/library/pdf/ImprovedGeometricSpecularAA.pdf
2232				float roughness2 = roughness * roughness;
2233				vec3 dndu = dFdx(normal), dndv = dFdy(normal);
2234				float variance = scene_data.roughness_limiter_amount * (dot(dndu, dndu) + dot(dndv, dndv));
2235				float kernelRoughness2 = min(2.0 * variance, scene_data.roughness_limiter_limit); //limit effect
2236				float filteredRoughness2 = min(1.0, roughness2 + kernelRoughness2);
2237				roughness = sqrt(filteredRoughness2);
2238			}
2239		#endif
2240			//apply energy conservation
2241		
2242			vec3 specular_light = vec3(0.0, 0.0, 0.0);
2243			vec3 diffuse_light = vec3(0.0, 0.0, 0.0);
2244			vec3 ambient_light = vec3(0.0, 0.0, 0.0);
2245		
2246		#ifndef MODE_UNSHADED
2247			// Used in regular draw pass and when drawing SDFs for SDFGI and materials for VoxelGI.
2248			emission *= scene_data.emissive_exposure_normalization;
2249		#endif
2250		
2251		#if !defined(MODE_RENDER_DEPTH) && !defined(MODE_UNSHADED)
2252		
2253			if (scene_data.use_reflection_cubemap) {
2254		#ifdef LIGHT_ANISOTROPY_USED
2255				// https://google.github.io/filament/Filament.html#lighting/imagebasedlights/anisotropy
2256				vec3 anisotropic_direction = anisotropy >= 0.0 ? binormal : tangent;
2257				vec3 anisotropic_tangent = cross(anisotropic_direction, view);
2258				vec3 anisotropic_normal = cross(anisotropic_tangent, anisotropic_direction);
2259				vec3 bent_normal = normalize(mix(normal, anisotropic_normal, abs(anisotropy) * clamp(5.0 * roughness, 0.0, 1.0)));
2260				vec3 ref_vec = reflect(-view, bent_normal);
2261				ref_vec = mix(ref_vec, bent_normal, roughness * roughness);
2262		#else
2263				vec3 ref_vec = reflect(-view, normal);
2264				ref_vec = mix(ref_vec, normal, roughness * roughness);
2265		#endif
2266		
2267				float horizon = min(1.0 + dot(ref_vec, normal), 1.0);
2268				ref_vec = scene_data.radiance_inverse_xform * ref_vec;
2269		#ifdef USE_RADIANCE_CUBEMAP_ARRAY
2270		
2271				float lod, blend;
2272		
2273				blend = modf(sqrt(roughness) * MAX_ROUGHNESS_LOD, lod);
2274				specular_light = texture(samplerCubeArray(radiance_cubemap, SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP), vec4(ref_vec, lod)).rgb;
2275				specular_light = mix(specular_light, texture(samplerCubeArray(radiance_cubemap, SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP), vec4(ref_vec, lod + 1)).rgb, blend);
2276		
2277		#else
2278				specular_light = textureLod(samplerCube(radiance_cubemap, SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP), ref_vec, sqrt(roughness) * MAX_ROUGHNESS_LOD).rgb;
2279		
2280		#endif //USE_RADIANCE_CUBEMAP_ARRAY
2281				specular_light *= scene_data.IBL_exposure_normalization;
2282				specular_light *= horizon * horizon;
2283				specular_light *= scene_data.ambient_light_color_energy.a;
2284			}
2285		
2286		#if defined(CUSTOM_RADIANCE_USED)
2287			specular_light = mix(specular_light, custom_radiance.rgb, custom_radiance.a);
2288		#endif
2289		
2290		#ifndef USE_LIGHTMAP
2291			//lightmap overrides everything
2292			if (scene_data.use_ambient_light) {
2293				ambient_light = scene_data.ambient_light_color_energy.rgb;
2294		
2295				if (scene_data.use_ambient_cubemap) {
2296					vec3 ambient_dir = scene_data.radiance_inverse_xform * normal;
2297		#ifdef USE_RADIANCE_CUBEMAP_ARRAY
2298					vec3 cubemap_ambient = texture(samplerCubeArray(radiance_cubemap, SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP), vec4(ambient_dir, MAX_ROUGHNESS_LOD)).rgb;
2299		#else
2300					vec3 cubemap_ambient = textureLod(samplerCube(radiance_cubemap, SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP), ambient_dir, MAX_ROUGHNESS_LOD).rgb;
2301		#endif //USE_RADIANCE_CUBEMAP_ARRAY
2302					cubemap_ambient *= scene_data.IBL_exposure_normalization;
2303					ambient_light = mix(ambient_light, cubemap_ambient * scene_data.ambient_light_color_energy.a, scene_data.ambient_color_sky_mix);
2304				}
2305			}
2306		#endif // USE_LIGHTMAP
2307		#if defined(CUSTOM_IRRADIANCE_USED)
2308			ambient_light = mix(ambient_light, custom_irradiance.rgb, custom_irradiance.a);
2309		#endif
2310		
2311		#ifdef LIGHT_CLEARCOAT_USED
2312		
2313			if (scene_data.use_reflection_cubemap) {
2314				vec3 n = normalize(normal_interp); // We want to use geometric normal, not normal_map
2315				float NoV = max(dot(n, view), 0.0001);
2316				vec3 ref_vec = reflect(-view, n);
2317				// The clear coat layer assumes an IOR of 1.5 (4% reflectance)
2318				float Fc = clearcoat * (0.04 + 0.96 * SchlickFresnel(NoV));
2319				float attenuation = 1.0 - Fc;
2320				ambient_light *= attenuation;
2321				specular_light *= attenuation;
2322		
2323				ref_vec = mix(ref_vec, n, clearcoat_roughness * clearcoat_roughness);
2324				float horizon = min(1.0 + dot(ref_vec, normal), 1.0);
2325				ref_vec = scene_data.radiance_inverse_xform * ref_vec;
2326				float roughness_lod = mix(0.001, 0.1, sqrt(clearcoat_roughness)) * MAX_ROUGHNESS_LOD;
2327		#ifdef USE_RADIANCE_CUBEMAP_ARRAY
2328		
2329				float lod, blend;
2330				blend = modf(roughness_lod, lod);
2331				vec3 clearcoat_light = texture(samplerCubeArray(radiance_cubemap, SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP), vec4(ref_vec, lod)).rgb;
2332				clearcoat_light = mix(clearcoat_light, texture(samplerCubeArray(radiance_cubemap, SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP), vec4(ref_vec, lod + 1)).rgb, blend);
2333		
2334		#else
2335				vec3 clearcoat_light = textureLod(samplerCube(radiance_cubemap, SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP), ref_vec, roughness_lod).rgb;
2336		
2337		#endif //USE_RADIANCE_CUBEMAP_ARRAY
2338				specular_light += clearcoat_light * horizon * horizon * Fc * scene_data.ambient_light_color_energy.a;
2339			}
2340		#endif
2341		#endif //!defined(MODE_RENDER_DEPTH) && !defined(MODE_UNSHADED)
2342		
2343			//radiance
2344		
2345		/// GI ///
2346		#if !defined(MODE_RENDER_DEPTH) && !defined(MODE_UNSHADED)
2347		
2348		#ifdef USE_LIGHTMAP
2349		
2350			//lightmap
2351			if (bool(instances.data[instance_index].flags & INSTANCE_FLAGS_USE_LIGHTMAP_CAPTURE)) { //has lightmap capture
2352				uint index = instances.data[instance_index].gi_offset;
2353		
2354				vec3 wnormal = mat3(scene_data.inv_view_matrix) * normal;
2355				const float c1 = 0.429043;
2356				const float c2 = 0.511664;
2357				const float c3 = 0.743125;
2358				const float c4 = 0.886227;
2359				const float c5 = 0.247708;
2360				ambient_light += (c1 * lightmap_captures.data[index].sh[8].rgb * (wnormal.x * wnormal.x - wnormal.y * wnormal.y) +
2361										 c3 * lightmap_captures.data[index].sh[6].rgb * wnormal.z * wnormal.z +
2362										 c4 * lightmap_captures.data[index].sh[0].rgb -
2363										 c5 * lightmap_captures.data[index].sh[6].rgb +
2364										 2.0 * c1 * lightmap_captures.data[index].sh[4].rgb * wnormal.x * wnormal.y +
2365										 2.0 * c1 * lightmap_captures.data[index].sh[7].rgb * wnormal.x * wnormal.z +
2366										 2.0 * c1 * lightmap_captures.data[index].sh[5].rgb * wnormal.y * wnormal.z +
2367										 2.0 * c2 * lightmap_captures.data[index].sh[3].rgb * wnormal.x +
2368										 2.0 * c2 * lightmap_captures.data[index].sh[1].rgb * wnormal.y +
2369										 2.0 * c2 * lightmap_captures.data[index].sh[2].rgb * wnormal.z) *
2370						scene_data.emissive_exposure_normalization;
2371		
2372			} else if (bool(instances.data[instance_index].flags & INSTANCE_FLAGS_USE_LIGHTMAP)) { // has actual lightmap
2373				bool uses_sh = bool(instances.data[instance_index].flags & INSTANCE_FLAGS_USE_SH_LIGHTMAP);
2374				uint ofs = instances.data[instance_index].gi_offset & 0xFFFF;
2375				uint slice = instances.data[instance_index].gi_offset >> 16;
2376				vec3 uvw;
2377				uvw.xy = uv2 * instances.data[instance_index].lightmap_uv_scale.zw + instances.data[instance_index].lightmap_uv_scale.xy;
2378				uvw.z = float(slice);
2379		
2380				if (uses_sh) {
2381					uvw.z *= 4.0; //SH textures use 4 times more data
2382					vec3 lm_light_l0 = textureLod(sampler2DArray(lightmap_textures[ofs], SAMPLER_LINEAR_CLAMP), uvw + vec3(0.0, 0.0, 0.0), 0.0).rgb;
2383					vec3 lm_light_l1n1 = textureLod(sampler2DArray(lightmap_textures[ofs], SAMPLER_LINEAR_CLAMP), uvw + vec3(0.0, 0.0, 1.0), 0.0).rgb;
2384					vec3 lm_light_l1_0 = textureLod(sampler2DArray(lightmap_textures[ofs], SAMPLER_LINEAR_CLAMP), uvw + vec3(0.0, 0.0, 2.0), 0.0).rgb;
2385					vec3 lm_light_l1p1 = textureLod(sampler2DArray(lightmap_textures[ofs], SAMPLER_LINEAR_CLAMP), uvw + vec3(0.0, 0.0, 3.0), 0.0).rgb;
2386		
2387					vec3 n = normalize(lightmaps.data[ofs].normal_xform * normal);
2388					float en = lightmaps.data[ofs].exposure_normalization;
2389		
2390					ambient_light += lm_light_l0 * 0.282095f * en;
2391					ambient_light += lm_light_l1n1 * 0.32573 * n.y * en;
2392					ambient_light += lm_light_l1_0 * 0.32573 * n.z * en;
2393					ambient_light += lm_light_l1p1 * 0.32573 * n.x * en;
2394					if (metallic > 0.01) { // since the more direct bounced light is lost, we can kind of fake it with this trick
2395						vec3 r = reflect(normalize(-vertex), normal);
2396						specular_light += lm_light_l1n1 * 0.32573 * r.y * en;
2397						specular_light += lm_light_l1_0 * 0.32573 * r.z * en;
2398						specular_light += lm_light_l1p1 * 0.32573 * r.x * en;
2399					}
2400		
2401				} else {
2402					ambient_light += textureLod(sampler2DArray(lightmap_textures[ofs], SAMPLER_LINEAR_CLAMP), uvw, 0.0).rgb * lightmaps.data[ofs].exposure_normalization;
2403				}
2404			}
2405		#else
2406		
2407			if (sc_use_forward_gi && bool(instances.data[instance_index].flags & INSTANCE_FLAGS_USE_SDFGI)) { //has lightmap capture
2408		
2409				//make vertex orientation the world one, but still align to camera
2410				vec3 cam_pos = mat3(scene_data.inv_view_matrix) * vertex;
2411				vec3 cam_normal = mat3(scene_data.inv_view_matrix) * normal;
2412				vec3 cam_reflection = mat3(scene_data.inv_view_matrix) * reflect(-view, normal);
2413		
2414				//apply y-mult
2415				cam_pos.y *= sdfgi.y_mult;
2416				cam_normal.y *= sdfgi.y_mult;
2417				cam_normal = normalize(cam_normal);
2418				cam_reflection.y *= sdfgi.y_mult;
2419				cam_normal = normalize(cam_normal);
2420				cam_reflection = normalize(cam_reflection);
2421		
2422				vec4 light_accum = vec4(0.0);
2423				float weight_accum = 0.0;
2424		
2425				vec4 light_blend_accum = vec4(0.0);
2426				float weight_blend_accum = 0.0;
2427		
2428				float blend = -1.0;
2429		
2430				// helper constants, compute once
2431		
2432				uint cascade = 0xFFFFFFFF;
2433				vec3 cascade_pos;
2434				vec3 cascade_normal;
2435		
2436				for (uint i = 0; i < sdfgi.max_cascades; i++) {
2437					cascade_pos = (cam_pos - sdfgi.cascades[i].position) * sdfgi.cascades[i].to_probe;
2438		
2439					if (any(lessThan(cascade_pos, vec3(0.0))) || any(greaterThanEqual(cascade_pos, sdfgi.cascade_probe_size))) {
2440						continue; //skip cascade
2441					}
2442		
2443					cascade = i;
2444					break;
2445				}
2446		
2447				if (cascade < SDFGI_MAX_CASCADES) {
2448					bool use_specular = true;
2449					float blend;
2450					vec3 diffuse, specular;
2451					sdfgi_process(cascade, cascade_pos, cam_pos, cam_normal, cam_reflection, use_specular, roughness, diffuse, specular, blend);
2452		
2453					if (blend > 0.0) {
2454						//blend
2455						if (cascade == sdfgi.max_cascades - 1) {
2456							diffuse = mix(diffuse, ambient_light, blend);
2457							if (use_specular) {
2458								specular = mix(specular, specular_light, blend);
2459							}
2460						} else {
2461							vec3 diffuse2, specular2;
2462							float blend2;
2463							cascade_pos = (cam_pos - sdfgi.cascades[cascade + 1].position) * sdfgi.cascades[cascade + 1].to_probe;
2464							sdfgi_process(cascade + 1, cascade_pos, cam_pos, cam_normal, cam_reflection, use_specular, roughness, diffuse2, specular2, blend2);
2465							diffuse = mix(diffuse, diffuse2, blend);
2466							if (use_specular) {
2467								specular = mix(specular, specular2, blend);
2468							}
2469						}
2470					}
2471		
2472					ambient_light = diffuse;
2473					if (use_specular) {
2474						specular_light = specular;
2475					}
2476				}
2477			}
2478		
2479			if (sc_use_forward_gi && bool(instances.data[instance_index].flags & INSTANCE_FLAGS_USE_VOXEL_GI)) { // process voxel_gi_instances
2480				uint index1 = instances.data[instance_index].gi_offset & 0xFFFF;
2481				// Make vertex orientation the world one, but still align to camera.
2482				vec3 cam_pos = mat3(scene_data.inv_view_matrix) * vertex;
2483				vec3 cam_normal = mat3(scene_data.inv_view_matrix) * normal;
2484				vec3 ref_vec = mat3(scene_data.inv_view_matrix) * normalize(reflect(-view, normal));
2485		
2486				//find arbitrary tangent and bitangent, then build a matrix
2487				vec3 v0 = abs(cam_normal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
2488				vec3 tangent = normalize(cross(v0, cam_normal));
2489				vec3 bitangent = normalize(cross(tangent, cam_normal));
2490				mat3 normal_mat = mat3(tangent, bitangent, cam_normal);
2491		
2492				vec4 amb_accum = vec4(0.0);
2493				vec4 spec_accum = vec4(0.0);
2494				voxel_gi_compute(index1, cam_pos, cam_normal, ref_vec, normal_mat, roughness * roughness, ambient_light, specular_light, spec_accum, amb_accum);
2495		
2496				uint index2 = instances.data[instance_index].gi_offset >> 16;
2497		
2498				if (index2 != 0xFFFF) {
2499					voxel_gi_compute(index2, cam_pos, cam_normal, ref_vec, normal_mat, roughness * roughness, ambient_light, specular_light, spec_accum, amb_accum);
2500				}
2501		
2502				if (amb_accum.a > 0.0) {
2503					amb_accum.rgb /= amb_accum.a;
2504				}
2505		
2506				if (spec_accum.a > 0.0) {
2507					spec_accum.rgb /= spec_accum.a;
2508				}
2509		
2510				specular_light = spec_accum.rgb;
2511				ambient_light = amb_accum.rgb;
2512			}
2513		
2514			if (!sc_use_forward_gi && bool(instances.data[instance_index].flags & INSTANCE_FLAGS_USE_GI_BUFFERS)) { //use GI buffers
2515		
2516				vec2 coord;
2517		
2518				if (implementation_data.gi_upscale_for_msaa) {
2519					vec2 base_coord = screen_uv;
2520					vec2 closest_coord = base_coord;
2521		#ifdef USE_MULTIVIEW
2522					float closest_ang = dot(normal, textureLod(sampler2DArray(normal_roughness_buffer, SAMPLER_LINEAR_CLAMP), vec3(base_coord, ViewIndex), 0.0).xyz * 2.0 - 1.0);
2523		#else // USE_MULTIVIEW
2524					float closest_ang = dot(normal, textureLod(sampler2D(normal_roughness_buffer, SAMPLER_LINEAR_CLAMP), base_coord, 0.0).xyz * 2.0 - 1.0);
2525		#endif // USE_MULTIVIEW
2526		
2527					for (int i = 0; i < 4; i++) {
2528						const vec2 neighbors[4] = vec2[](vec2(-1, 0), vec2(1, 0), vec2(0, -1), vec2(0, 1));
2529						vec2 neighbour_coord = base_coord + neighbors[i] * scene_data.screen_pixel_size;
2530		#ifdef USE_MULTIVIEW
2531						float neighbour_ang = dot(normal, textureLod(sampler2DArray(normal_roughness_buffer, SAMPLER_LINEAR_CLAMP), vec3(neighbour_coord, ViewIndex), 0.0).xyz * 2.0 - 1.0);
2532		#else // USE_MULTIVIEW
2533						float neighbour_ang = dot(normal, textureLod(sampler2D(normal_roughness_buffer, SAMPLER_LINEAR_CLAMP), neighbour_coord, 0.0).xyz * 2.0 - 1.0);
2534		#endif // USE_MULTIVIEW
2535						if (neighbour_ang > closest_ang) {
2536							closest_ang = neighbour_ang;
2537							closest_coord = neighbour_coord;
2538						}
2539					}
2540		
2541					coord = closest_coord;
2542		
2543				} else {
2544					coord = screen_uv;
2545				}
2546		
2547		#ifdef USE_MULTIVIEW
2548				vec4 buffer_ambient = textureLod(sampler2DArray(ambient_buffer, SAMPLER_LINEAR_CLAMP), vec3(coord, ViewIndex), 0.0);
2549				vec4 buffer_reflection = textureLod(sampler2DArray(reflection_buffer, SAMPLER_LINEAR_CLAMP), vec3(coord, ViewIndex), 0.0);
2550		#else // USE_MULTIVIEW
2551				vec4 buffer_ambient = textureLod(sampler2D(ambient_buffer, SAMPLER_LINEAR_CLAMP), coord, 0.0);
2552				vec4 buffer_reflection = textureLod(sampler2D(reflection_buffer, SAMPLER_LINEAR_CLAMP), coord, 0.0);
2553		#endif // USE_MULTIVIEW
2554		
2555				ambient_light = mix(ambient_light, buffer_ambient.rgb, buffer_ambient.a);
2556				specular_light = mix(specular_light, buffer_reflection.rgb, buffer_reflection.a);
2557			}
2558		#endif // !USE_LIGHTMAP
2559		
2560			if (bool(implementation_data.ss_effects_flags & SCREEN_SPACE_EFFECTS_FLAGS_USE_SSAO)) {
2561		#ifdef USE_MULTIVIEW
2562				float ssao = texture(sampler2DArray(ao_buffer, SAMPLER_LINEAR_CLAMP), vec3(screen_uv, ViewIndex)).r;
2563		#else
2564				float ssao = texture(sampler2D(ao_buffer, SAMPLER_LINEAR_CLAMP), screen_uv).r;
2565		#endif
2566				ao = min(ao, ssao);
2567				ao_light_affect = mix(ao_light_affect, max(ao_light_affect, implementation_data.ssao_light_affect), implementation_data.ssao_ao_affect);
2568			}
2569		
2570			{ // process reflections
2571		
2572				vec4 reflection_accum = vec4(0.0, 0.0, 0.0, 0.0);
2573				vec4 ambient_accum = vec4(0.0, 0.0, 0.0, 0.0);
2574		
2575				uint cluster_reflection_offset = cluster_offset + implementation_data.cluster_type_size * 3;
2576		
2577				uint item_min;
2578				uint item_max;
2579				uint item_from;
2580				uint item_to;
2581		
2582				cluster_get_item_range(cluster_reflection_offset + implementation_data.max_cluster_element_count_div_32 + cluster_z, item_min, item_max, item_from, item_to);
2583		
2584		#ifdef USE_SUBGROUPS
2585				item_from = subgroupBroadcastFirst(subgroupMin(item_from));
2586				item_to = subgroupBroadcastFirst(subgroupMax(item_to));
2587		#endif
2588		
2589		#ifdef LIGHT_ANISOTROPY_USED
2590				// https://google.github.io/filament/Filament.html#lighting/imagebasedlights/anisotropy
2591				vec3 anisotropic_direction = anisotropy >= 0.0 ? binormal : tangent;
2592				vec3 anisotropic_tangent = cross(anisotropic_direction, view);
2593				vec3 anisotropic_normal = cross(anisotropic_tangent, anisotropic_direction);
2594				vec3 bent_normal = normalize(mix(normal, anisotropic_normal, abs(anisotropy) * clamp(5.0 * roughness, 0.0, 1.0)));
2595		#else
2596				vec3 bent_normal = normal;
2597		#endif
2598				vec3 ref_vec = normalize(reflect(-view, bent_normal));
2599				ref_vec = mix(ref_vec, bent_normal, roughness * roughness);
2600		
2601				for (uint i = item_from; i < item_to; i++) {
2602					uint mask = cluster_buffer.data[cluster_reflection_offset + i];
2603					mask &= cluster_get_range_clip_mask(i, item_min, item_max);
2604		#ifdef USE_SUBGROUPS
2605					uint merged_mask = subgroupBroadcastFirst(subgroupOr(mask));
2606		#else
2607					uint merged_mask = mask;
2608		#endif
2609		
2610					while (merged_mask != 0) {
2611						uint bit = findMSB(merged_mask);
2612						merged_mask &= ~(1u << bit);
2613		#ifdef USE_SUBGROUPS
2614						if (((1u << bit) & mask) == 0) { //do not process if not originally here
2615							continue;
2616						}
2617		#endif
2618						uint reflection_index = 32 * i + bit;
2619		
2620						if (!bool(reflections.data[reflection_index].mask & instances.data[instance_index].layer_mask)) {
2621							continue; //not masked
2622						}
2623		
2624						reflection_process(reflection_index, vertex, ref_vec, normal, roughness, ambient_light, specular_light, ambient_accum, reflection_accum);
2625					}
2626				}
2627		
2628				if (reflection_accum.a > 0.0) {
2629					specular_light = reflection_accum.rgb / reflection_accum.a;
2630				}
2631		
2632		#if !defined(USE_LIGHTMAP)
2633				if (ambient_accum.a > 0.0) {
2634					ambient_light = ambient_accum.rgb / ambient_accum.a;
2635				}
2636		#endif
2637			}
2638		
2639			//finalize ambient light here
2640			{
2641		#if defined(AMBIENT_LIGHT_DISABLED)
2642				ambient_light = vec3(0.0, 0.0, 0.0);
2643		#else
2644				ambient_light *= albedo.rgb;
2645				ambient_light *= ao;
2646		
2647				if (bool(implementation_data.ss_effects_flags & SCREEN_SPACE_EFFECTS_FLAGS_USE_SSIL)) {
2648		#ifdef USE_MULTIVIEW
2649					vec4 ssil = textureLod(sampler2DArray(ssil_buffer, SAMPLER_LINEAR_CLAMP), vec3(screen_uv, ViewIndex), 0.0);
2650		#else
2651					vec4 ssil = textureLod(sampler2D(ssil_buffer, SAMPLER_LINEAR_CLAMP), screen_uv, 0.0);
2652		#endif // USE_MULTIVIEW
2653					ambient_light *= 1.0 - ssil.a;
2654					ambient_light += ssil.rgb * albedo.rgb;
2655				}
2656		#endif // AMBIENT_LIGHT_DISABLED
2657			}
2658		
2659			// convert ao to direct light ao
2660			ao = mix(1.0, ao, ao_light_affect);
2661		
2662			//this saves some VGPRs
2663			vec3 f0 = F0(metallic, specular, albedo);
2664		
2665			{
2666		#if defined(DIFFUSE_TOON)
2667				//simplify for toon, as
2668				specular_light *= specular * metallic * albedo * 2.0;
2669		#else
2670		
2671				// scales the specular reflections, needs to be computed before lighting happens,
2672				// but after environment, GI, and reflection probes are added
2673				// Environment brdf approximation (Lazarov 2013)
2674				// see https://www.unrealengine.com/en-US/blog/physically-based-shading-on-mobile
2675				const vec4 c0 = vec4(-1.0, -0.0275, -0.572, 0.022);
2676				const vec4 c1 = vec4(1.0, 0.0425, 1.04, -0.04);
2677				vec4 r = roughness * c0 + c1;
2678				float ndotv = clamp(dot(normal, view), 0.0, 1.0);
2679				float a004 = min(r.x * r.x, exp2(-9.28 * ndotv)) * r.x + r.y;
2680				vec2 env = vec2(-1.04, 1.04) * a004 + r.zw;
2681		
2682				specular_light *= env.x * f0 + env.y * clamp(50.0 * f0.g, metallic, 1.0);
2683		#endif
2684			}
2685		
2686		#endif //GI !defined(MODE_RENDER_DEPTH) && !defined(MODE_UNSHADED)
2687		
2688		#if !defined(MODE_RENDER_DEPTH)
2689			//this saves some VGPRs
2690			uint orms = packUnorm4x8(vec4(ao, roughness, metallic, specular));
2691		#endif
2692		
2693		// LIGHTING
2694		#if !defined(MODE_RENDER_DEPTH) && !defined(MODE_UNSHADED)
2695		
2696			{ // Directional light.
2697		
2698				// Do shadow and lighting in two passes to reduce register pressure.
2699		#ifndef SHADOWS_DISABLED
2700				uint shadow0 = 0;
2701				uint shadow1 = 0;
2702		
2703				for (uint i = 0; i < 8; i++) {
2704					if (i >= scene_data.directional_light_count) {
2705						break;
2706					}
2707		
2708					if (!bool(directional_lights.data[i].mask & instances.data[instance_index].layer_mask)) {
2709						continue; //not masked
2710					}
2711		
2712					if (directional_lights.data[i].bake_mode == LIGHT_BAKE_STATIC && bool(instances.data[instance_index].flags & INSTANCE_FLAGS_USE_LIGHTMAP)) {
2713						continue; // Statically baked light and object uses lightmap, skip
2714					}
2715		
2716					float shadow = 1.0;
2717		
2718					if (directional_lights.data[i].shadow_opacity > 0.001) {
2719						float depth_z = -vertex.z;
2720						vec3 light_dir = directional_lights.data[i].direction;
2721						vec3 base_normal_bias = normalize(normal_interp) * (1.0 - max(0.0, dot(light_dir, -normalize(normal_interp))));
2722		
2723		#define BIAS_FUNC(m_var, m_idx)                                                                 \
2724			m_var.xyz += light_dir * directional_lights.data[i].shadow_bias[m_idx];                     \
2725			vec3 normal_bias = base_normal_bias * directional_lights.data[i].shadow_normal_bias[m_idx]; \
2726			normal_bias -= light_dir * dot(light_dir, normal_bias);                                     \
2727			m_var.xyz += normal_bias;
2728		
2729						//version with soft shadows, more expensive
2730						if (sc_use_directional_soft_shadows && directional_lights.data[i].softshadow_angle > 0) {
2731							uint blend_count = 0;
2732							const uint blend_max = directional_lights.data[i].blend_splits ? 2 : 1;
2733		
2734							if (depth_z < directional_lights.data[i].shadow_split_offsets.x) {
2735								vec4 v = vec4(vertex, 1.0);
2736		
2737								BIAS_FUNC(v, 0)
2738		
2739								vec4 pssm_coord = (directional_lights.data[i].shadow_matrix1 * v);
2740								pssm_coord /= pssm_coord.w;
2741		
2742								float range_pos = dot(directional_lights.data[i].direction, v.xyz);
2743								float range_begin = directional_lights.data[i].shadow_range_begin.x;
2744								float test_radius = (range_pos - range_begin) * directional_lights.data[i].softshadow_angle;
2745								vec2 tex_scale = directional_lights.data[i].uv_scale1 * test_radius;
2746								shadow = sample_directional_soft_shadow(directional_shadow_atlas, pssm_coord.xyz, tex_scale * directional_lights.data[i].soft_shadow_scale);
2747								blend_count++;
2748							}
2749		
2750							if (blend_count < blend_max && depth_z < directional_lights.data[i].shadow_split_offsets.y) {
2751								vec4 v = vec4(vertex, 1.0);
2752		
2753								BIAS_FUNC(v, 1)
2754		
2755								vec4 pssm_coord = (directional_lights.data[i].shadow_matrix2 * v);
2756								pssm_coord /= pssm_coord.w;
2757		
2758								float range_pos = dot(directional_lights.data[i].direction, v.xyz);
2759								float range_begin = directional_lights.data[i].shadow_range_begin.y;
2760								float test_radius = (range_pos - range_begin) * directional_lights.data[i].softshadow_angle;
2761								vec2 tex_scale = directional_lights.data[i].uv_scale2 * test_radius;
2762								float s = sample_directional_soft_shadow(directional_shadow_atlas, pssm_coord.xyz, tex_scale * directional_lights.data[i].soft_shadow_scale);
2763		
2764								if (blend_count == 0) {
2765									shadow = s;
2766								} else {
2767									//blend
2768									float blend = smoothstep(0.0, directional_lights.data[i].shadow_split_offsets.x, depth_z);
2769									shadow = mix(shadow, s, blend);
2770								}
2771		
2772								blend_count++;
2773							}
2774		
2775							if (blend_count < blend_max && depth_z < directional_lights.data[i].shadow_split_offsets.z) {
2776								vec4 v = vec4(vertex, 1.0);
2777		
2778								BIAS_FUNC(v, 2)
2779		
2780								vec4 pssm_coord = (directional_lights.data[i].shadow_matrix3 * v);
2781								pssm_coord /= pssm_coord.w;
2782		
2783								float range_pos = dot(directional_lights.data[i].direction, v.xyz);
2784								float range_begin = directional_lights.data[i].shadow_range_begin.z;
2785								float test_radius = (range_pos - range_begin) * directional_lights.data[i].softshadow_angle;
2786								vec2 tex_scale = directional_lights.data[i].uv_scale3 * test_radius;
2787								float s = sample_directional_soft_shadow(directional_shadow_atlas, pssm_coord.xyz, tex_scale * directional_lights.data[i].soft_shadow_scale);
2788		
2789								if (blend_count == 0) {
2790									shadow = s;
2791								} else {
2792									//blend
2793									float blend = smoothstep(directional_lights.data[i].shadow_split_offsets.x, directional_lights.data[i].shadow_split_offsets.y, depth_z);
2794									shadow = mix(shadow, s, blend);
2795								}
2796		
2797								blend_count++;
2798							}
2799		
2800							if (blend_count < blend_max) {
2801								vec4 v = vec4(vertex, 1.0);
2802		
2803								BIAS_FUNC(v, 3)
2804		
2805								vec4 pssm_coord = (directional_lights.data[i].shadow_matrix4 * v);
2806								pssm_coord /= pssm_coord.w;
2807		
2808								float range_pos = dot(directional_lights.data[i].direction, v.xyz);
2809								float range_begin = directional_lights.data[i].shadow_range_begin.w;
2810								float test_radius = (range_pos - range_begin) * directional_lights.data[i].softshadow_angle;
2811								vec2 tex_scale = directional_lights.data[i].uv_scale4 * test_radius;
2812								float s = sample_directional_soft_shadow(directional_shadow_atlas, pssm_coord.xyz, tex_scale * directional_lights.data[i].soft_shadow_scale);
2813		
2814								if (blend_count == 0) {
2815									shadow = s;
2816								} else {
2817									//blend
2818									float blend = smoothstep(directional_lights.data[i].shadow_split_offsets.y, directional_lights.data[i].shadow_split_offsets.z, depth_z);
2819									shadow = mix(shadow, s, blend);
2820								}
2821							}
2822		
2823						} else { //no soft shadows
2824		
2825							vec4 pssm_coord;
2826							float blur_factor;
2827		
2828							if (depth_z < directional_lights.data[i].shadow_split_offsets.x) {
2829								vec4 v = vec4(vertex, 1.0);
2830		
2831								BIAS_FUNC(v, 0)
2832		
2833								pssm_coord = (directional_lights.data[i].shadow_matrix1 * v);
2834								blur_factor = 1.0;
2835							} else if (depth_z < directional_lights.data[i].shadow_split_offsets.y) {
2836								vec4 v = vec4(vertex, 1.0);
2837		
2838								BIAS_FUNC(v, 1)
2839		
2840								pssm_coord = (directional_lights.data[i].shadow_matrix2 * v);
2841								// Adjust shadow blur with reference to the first split to reduce discrepancy between shadow splits.
2842								blur_factor = directional_lights.data[i].shadow_split_offsets.x / directional_lights.data[i].shadow_split_offsets.y;
2843							} else if (depth_z < directional_lights.data[i].shadow_split_offsets.z) {
2844								vec4 v = vec4(vertex, 1.0);
2845		
2846								BIAS_FUNC(v, 2)
2847		
2848								pssm_coord = (directional_lights.data[i].shadow_matrix3 * v);
2849								// Adjust shadow blur with reference to the first split to reduce discrepancy between shadow splits.
2850								blur_factor = directional_lights.data[i].shadow_split_offsets.x / directional_lights.data[i].shadow_split_offsets.z;
2851							} else {
2852								vec4 v = vec4(vertex, 1.0);
2853		
2854								BIAS_FUNC(v, 3)
2855		
2856								pssm_coord = (directional_lights.data[i].shadow_matrix4 * v);
2857								// Adjust shadow blur with reference to the first split to reduce discrepancy between shadow splits.
2858								blur_factor = directional_lights.data[i].shadow_split_offsets.x / directional_lights.data[i].shadow_split_offsets.w;
2859							}
2860		
2861							pssm_coord /= pssm_coord.w;
2862		
2863							shadow = sample_directional_pcf_shadow(directional_shadow_atlas, scene_data.directional_shadow_pixel_size * directional_lights.data[i].soft_shadow_scale * blur_factor, pssm_coord);
2864		
2865							if (directional_lights.data[i].blend_splits) {
2866								float pssm_blend;
2867								float blur_factor2;
2868		
2869								if (depth_z < directional_lights.data[i].shadow_split_offsets.x) {
2870									vec4 v = vec4(vertex, 1.0);
2871									BIAS_FUNC(v, 1)
2872									pssm_coord = (directional_lights.data[i].shadow_matrix2 * v);
2873									pssm_blend = smoothstep(0.0, directional_lights.data[i].shadow_split_offsets.x, depth_z);
2874									// Adjust shadow blur with reference to the first split to reduce discrepancy between shadow splits.
2875									blur_factor2 = directional_lights.data[i].shadow_split_offsets.x / directional_lights.data[i].shadow_split_offsets.y;
2876								} else if (depth_z < directional_lights.data[i].shadow_split_offsets.y) {
2877									vec4 v = vec4(vertex, 1.0);
2878									BIAS_FUNC(v, 2)
2879									pssm_coord = (directional_lights.data[i].shadow_matrix3 * v);
2880									pssm_blend = smoothstep(directional_lights.data[i].shadow_split_offsets.x, directional_lights.data[i].shadow_split_offsets.y, depth_z);
2881									// Adjust shadow blur with reference to the first split to reduce discrepancy between shadow splits.
2882									blur_factor2 = directional_lights.data[i].shadow_split_offsets.x / directional_lights.data[i].shadow_split_offsets.z;
2883								} else if (depth_z < directional_lights.data[i].shadow_split_offsets.z) {
2884									vec4 v = vec4(vertex, 1.0);
2885									BIAS_FUNC(v, 3)
2886									pssm_coord = (directional_lights.data[i].shadow_matrix4 * v);
2887									pssm_blend = smoothstep(directional_lights.data[i].shadow_split_offsets.y, directional_lights.data[i].shadow_split_offsets.z, depth_z);
2888									// Adjust shadow blur with reference to the first split to reduce discrepancy between shadow splits.
2889									blur_factor2 = directional_lights.data[i].shadow_split_offsets.x / directional_lights.data[i].shadow_split_offsets.w;
2890								} else {
2891									pssm_blend = 0.0; //if no blend, same coord will be used (divide by z will result in same value, and already cached)
2892									blur_factor2 = 1.0;
2893								}
2894		
2895								pssm_coord /= pssm_coord.w;
2896		
2897								float shadow2 = sample_directional_pcf_shadow(directional_shadow_atlas, scene_data.directional_shadow_pixel_size * directional_lights.data[i].soft_shadow_scale * blur_factor2, pssm_coord);
2898								shadow = mix(shadow, shadow2, pssm_blend);
2899							}
2900						}
2901		
2902						shadow = mix(shadow, 1.0, smoothstep(directional_lights.data[i].fade_from, directional_lights.data[i].fade_to, vertex.z)); //done with negative values for performance
2903		
2904		#undef BIAS_FUNC
2905					} // shadows
2906		
2907					if (i < 4) {
2908						shadow0 |= uint(clamp(shadow * 255.0, 0.0, 255.0)) << (i * 8);
2909					} else {
2910						shadow1 |= uint(clamp(shadow * 255.0, 0.0, 255.0)) << ((i - 4) * 8);
2911					}
2912				}
2913		#endif // SHADOWS_DISABLED
2914		
2915				for (uint i = 0; i < 8; i++) {
2916					if (i >= scene_data.directional_light_count) {
2917						break;
2918					}
2919		
2920					if (!bool(directional_lights.data[i].mask & instances.data[instance_index].layer_mask)) {
2921						continue; //not masked
2922					}
2923		
2924		#ifdef LIGHT_TRANSMITTANCE_USED
2925					float transmittance_z = transmittance_depth;
2926		
2927					if (directional_lights.data[i].shadow_opacity > 0.001) {
2928						float depth_z = -vertex.z;
2929		
2930						if (depth_z < directional_lights.data[i].shadow_split_offsets.x) {
2931							vec4 trans_vertex = vec4(vertex - normalize(normal_interp) * directional_lights.data[i].shadow_transmittance_bias.x, 1.0);
2932							vec4 trans_coord = directional_lights.data[i].shadow_matrix1 * trans_vertex;
2933							trans_coord /= trans_coord.w;
2934		
2935							float shadow_z = textureLod(sampler2D(directional_shadow_atlas, SAMPLER_LINEAR_CLAMP), trans_coord.xy, 0.0).r;
2936							shadow_z *= directional_lights.data[i].shadow_z_range.x;
2937							float z = trans_coord.z * directional_lights.data[i].shadow_z_range.x;
2938		
2939							transmittance_z = z - shadow_z;
2940						} else if (depth_z < directional_lights.data[i].shadow_split_offsets.y) {
2941							vec4 trans_vertex = vec4(vertex - normalize(normal_interp) * directional_lights.data[i].shadow_transmittance_bias.y, 1.0);
2942							vec4 trans_coord = directional_lights.data[i].shadow_matrix2 * trans_vertex;
2943							trans_coord /= trans_coord.w;
2944		
2945							float shadow_z = textureLod(sampler2D(directional_shadow_atlas, SAMPLER_LINEAR_CLAMP), trans_coord.xy, 0.0).r;
2946							shadow_z *= directional_lights.data[i].shadow_z_range.y;
2947							float z = trans_coord.z * directional_lights.data[i].shadow_z_range.y;
2948		
2949							transmittance_z = z - shadow_z;
2950						} else if (depth_z < directional_lights.data[i].shadow_split_offsets.z) {
2951							vec4 trans_vertex = vec4(vertex - normalize(normal_interp) * directional_lights.data[i].shadow_transmittance_bias.z, 1.0);
2952							vec4 trans_coord = directional_lights.data[i].shadow_matrix3 * trans_vertex;
2953							trans_coord /= trans_coord.w;
2954		
2955							float shadow_z = textureLod(sampler2D(directional_shadow_atlas, SAMPLER_LINEAR_CLAMP), trans_coord.xy, 0.0).r;
2956							shadow_z *= directional_lights.data[i].shadow_z_range.z;
2957							float z = trans_coord.z * directional_lights.data[i].shadow_z_range.z;
2958		
2959							transmittance_z = z - shadow_z;
2960		
2961						} else {
2962							vec4 trans_vertex = vec4(vertex - normalize(normal_interp) * directional_lights.data[i].shadow_transmittance_bias.w, 1.0);
2963							vec4 trans_coord = directional_lights.data[i].shadow_matrix4 * trans_vertex;
2964							trans_coord /= trans_coord.w;
2965		
2966							float shadow_z = textureLod(sampler2D(directional_shadow_atlas, SAMPLER_LINEAR_CLAMP), trans_coord.xy, 0.0).r;
2967							shadow_z *= directional_lights.data[i].shadow_z_range.w;
2968							float z = trans_coord.z * directional_lights.data[i].shadow_z_range.w;
2969		
2970							transmittance_z = z - shadow_z;
2971						}
2972					}
2973		#endif
2974		
2975					float shadow = 1.0;
2976		#ifndef SHADOWS_DISABLED
2977					if (i < 4) {
2978						shadow = float(shadow0 >> (i * 8u) & 0xFFu) / 255.0;
2979					} else {
2980						shadow = float(shadow1 >> ((i - 4u) * 8u) & 0xFFu) / 255.0;
2981					}
2982		
2983					shadow = mix(1.0, shadow, directional_lights.data[i].shadow_opacity);
2984		#endif
2985		
2986					blur_shadow(shadow);
2987		
2988		#ifdef DEBUG_DRAW_PSSM_SPLITS
2989					vec3 tint = vec3(1.0);
2990					if (-vertex.z < directional_lights.data[i].shadow_split_offsets.x) {
2991						tint = vec3(1.0, 0.0, 0.0);
2992					} else if (-vertex.z < directional_lights.data[i].shadow_split_offsets.y) {
2993						tint = vec3(0.0, 1.0, 0.0);
2994					} else if (-vertex.z < directional_lights.data[i].shadow_split_offsets.z) {
2995						tint = vec3(0.0, 0.0, 1.0);
2996					} else {
2997						tint = vec3(1.0, 1.0, 0.0);
2998					}
2999					tint = mix(tint, vec3(1.0), shadow);
3000					shadow = 1.0;
3001		#endif
3002		
3003					float size_A = sc_use_light_soft_shadows ? directional_lights.data[i].size : 0.0;
3004		
3005					light_compute(normal, directional_lights.data[i].direction, normalize(view), size_A,
3006		#ifndef DEBUG_DRAW_PSSM_SPLITS
3007							directional_lights.data[i].color * directional_lights.data[i].energy,
3008		#else
3009							directional_lights.data[i].color * directional_lights.data[i].energy * tint,
3010		#endif
3011							true, shadow, f0, orms, 1.0, albedo, alpha,
3012		#ifdef LIGHT_BACKLIGHT_USED
3013							backlight,
3014		#endif
3015		#ifdef LIGHT_TRANSMITTANCE_USED
3016							transmittance_color,
3017							transmittance_depth,
3018							transmittance_boost,
3019							transmittance_z,
3020		#endif
3021		#ifdef LIGHT_RIM_USED
3022							rim, rim_tint,
3023		#endif
3024		#ifdef LIGHT_CLEARCOAT_USED
3025							clearcoat, clearcoat_roughness, normalize(normal_interp),
3026		#endif
3027		#ifdef LIGHT_ANISOTROPY_USED
3028							binormal,
3029							tangent, anisotropy,
3030		#endif
3031							diffuse_light,
3032							specular_light);
3033				}
3034			}
3035		
3036			{ //omni lights
3037		
3038				uint cluster_omni_offset = cluster_offset;
3039		
3040				uint item_min;
3041				uint item_max;
3042				uint item_from;
3043				uint item_to;
3044		
3045				cluster_get_item_range(cluster_omni_offset + implementation_data.max_cluster_element_count_div_32 + cluster_z, item_min, item_max, item_from, item_to);
3046		
3047		#ifdef USE_SUBGROUPS
3048				item_from = subgroupBroadcastFirst(subgroupMin(item_from));
3049				item_to = subgroupBroadcastFirst(subgroupMax(item_to));
3050		#endif
3051		
3052				for (uint i = item_from; i < item_to; i++) {
3053					uint mask = cluster_buffer.data[cluster_omni_offset + i];
3054					mask &= cluster_get_range_clip_mask(i, item_min, item_max);
3055		#ifdef USE_SUBGROUPS
3056					uint merged_mask = subgroupBroadcastFirst(subgroupOr(mask));
3057		#else
3058					uint merged_mask = mask;
3059		#endif
3060		
3061					while (merged_mask != 0) {
3062						uint bit = findMSB(merged_mask);
3063						merged_mask &= ~(1u << bit);
3064		#ifdef USE_SUBGROUPS
3065						if (((1u << bit) & mask) == 0) { //do not process if not originally here
3066							continue;
3067						}
3068		#endif
3069						uint light_index = 32 * i + bit;
3070		
3071						if (!bool(omni_lights.data[light_index].mask & instances.data[instance_index].layer_mask)) {
3072							continue; //not masked
3073						}
3074		
3075						if (omni_lights.data[light_index].bake_mode == LIGHT_BAKE_STATIC && bool(instances.data[instance_index].flags & INSTANCE_FLAGS_USE_LIGHTMAP)) {
3076							continue; // Statically baked light and object uses lightmap, skip
3077						}
3078		
3079						float shadow = light_process_omni_shadow(light_index, vertex, normal);
3080		
3081						shadow = blur_shadow(shadow);
3082		
3083						light_process_omni(light_index, vertex, view, normal, vertex_ddx, vertex_ddy, f0, orms, shadow, albedo, alpha,
3084		#ifdef LIGHT_BACKLIGHT_USED
3085								backlight,
3086		#endif
3087		#ifdef LIGHT_TRANSMITTANCE_USED
3088								transmittance_color,
3089								transmittance_depth,
3090								transmittance_boost,
3091		#endif
3092		#ifdef LIGHT_RIM_USED
3093								rim,
3094								rim_tint,
3095		#endif
3096		#ifdef LIGHT_CLEARCOAT_USED
3097								clearcoat, clearcoat_roughness, normalize(normal_interp),
3098		#endif
3099		#ifdef LIGHT_ANISOTROPY_USED
3100								tangent, binormal, anisotropy,
3101		#endif
3102								diffuse_light, specular_light);
3103					}
3104				}
3105			}
3106		
3107			{ //spot lights
3108		
3109				uint cluster_spot_offset = cluster_offset + implementation_data.cluster_type_size;
3110		
3111				uint item_min;
3112				uint item_max;
3113				uint item_from;
3114				uint item_to;
3115		
3116				cluster_get_item_range(cluster_spot_offset + implementation_data.max_cluster_element_count_div_32 + cluster_z, item_min, item_max, item_from, item_to);
3117		
3118		#ifdef USE_SUBGROUPS
3119				item_from = subgroupBroadcastFirst(subgroupMin(item_from));
3120				item_to = subgroupBroadcastFirst(subgroupMax(item_to));
3121		#endif
3122		
3123				for (uint i = item_from; i < item_to; i++) {
3124					uint mask = cluster_buffer.data[cluster_spot_offset + i];
3125					mask &= cluster_get_range_clip_mask(i, item_min, item_max);
3126		#ifdef USE_SUBGROUPS
3127					uint merged_mask = subgroupBroadcastFirst(subgroupOr(mask));
3128		#else
3129					uint merged_mask = mask;
3130		#endif
3131		
3132					while (merged_mask != 0) {
3133						uint bit = findMSB(merged_mask);
3134						merged_mask &= ~(1u << bit);
3135		#ifdef USE_SUBGROUPS
3136						if (((1u << bit) & mask) == 0) { //do not process if not originally here
3137							continue;
3138						}
3139		#endif
3140		
3141						uint light_index = 32 * i + bit;
3142		
3143						if (!bool(spot_lights.data[light_index].mask & instances.data[instance_index].layer_mask)) {
3144							continue; //not masked
3145						}
3146		
3147						if (spot_lights.data[light_index].bake_mode == LIGHT_BAKE_STATIC && bool(instances.data[instance_index].flags & INSTANCE_FLAGS_USE_LIGHTMAP)) {
3148							continue; // Statically baked light and object uses lightmap, skip
3149						}
3150		
3151						float shadow = light_process_spot_shadow(light_index, vertex, normal);
3152		
3153						shadow = blur_shadow(shadow);
3154		
3155						light_process_spot(light_index, vertex, view, normal, vertex_ddx, vertex_ddy, f0, orms, shadow, albedo, alpha,
3156		#ifdef LIGHT_BACKLIGHT_USED
3157								backlight,
3158		#endif
3159		#ifdef LIGHT_TRANSMITTANCE_USED
3160								transmittance_color,
3161								transmittance_depth,
3162								transmittance_boost,
3163		#endif
3164		#ifdef LIGHT_RIM_USED
3165								rim,
3166								rim_tint,
3167		#endif
3168		#ifdef LIGHT_CLEARCOAT_USED
3169								clearcoat, clearcoat_roughness, normalize(normal_interp),
3170		#endif
3171		#ifdef LIGHT_ANISOTROPY_USED
3172								tangent,
3173								binormal, anisotropy,
3174		#endif
3175								diffuse_light, specular_light);
3176					}
3177				}
3178			}
3179		
3180		#ifdef USE_SHADOW_TO_OPACITY
3181			alpha = min(alpha, clamp(length(ambient_light), 0.0, 1.0));
3182		
3183		#if defined(ALPHA_SCISSOR_USED)
3184			if (alpha < alpha_scissor) {
3185				discard;
3186			}
3187		#else
3188		#ifdef MODE_RENDER_DEPTH
3189		#ifdef USE_OPAQUE_PREPASS
3190		
3191			if (alpha < scene_data.opaque_prepass_threshold) {
3192				discard;
3193			}
3194		
3195		#endif // USE_OPAQUE_PREPASS
3196		#endif // MODE_RENDER_DEPTH
3197		#endif // ALPHA_SCISSOR_USED
3198		
3199		#endif // USE_SHADOW_TO_OPACITY
3200		
3201		#endif //!defined(MODE_RENDER_DEPTH) && !defined(MODE_UNSHADED)
3202		
3203		#ifdef MODE_RENDER_DEPTH
3204		
3205		#ifdef MODE_RENDER_SDF
3206		
3207			{
3208				vec3 local_pos = (implementation_data.sdf_to_bounds * vec4(vertex, 1.0)).xyz;
3209				ivec3 grid_pos = implementation_data.sdf_offset + ivec3(local_pos * vec3(implementation_data.sdf_size));
3210		
3211				uint albedo16 = 0x1; //solid flag
3212				albedo16 |= clamp(uint(albedo.r * 31.0), 0, 31) << 11;
3213				albedo16 |= clamp(uint(albedo.g * 31.0), 0, 31) << 6;
3214				albedo16 |= clamp(uint(albedo.b * 31.0), 0, 31) << 1;
3215		
3216				imageStore(albedo_volume_grid, grid_pos, uvec4(albedo16));
3217		
3218				uint facing_bits = 0;
3219				const vec3 aniso_dir[6] = vec3[](
3220						vec3(1, 0, 0),
3221						vec3(0, 1, 0),
3222						vec3(0, 0, 1),
3223						vec3(-1, 0, 0),
3224						vec3(0, -1, 0),
3225						vec3(0, 0, -1));
3226		
3227				vec3 cam_normal = mat3(scene_data.inv_view_matrix) * normalize(normal_interp);
3228		
3229				float closest_dist = -1e20;
3230		
3231				for (uint i = 0; i < 6; i++) {
3232					float d = dot(cam_normal, aniso_dir[i]);
3233					if (d > closest_dist) {
3234						closest_dist = d;
3235						facing_bits = (1 << i);
3236					}
3237				}
3238		
3239		#ifdef MOLTENVK_USED
3240				imageStore(geom_facing_grid, grid_pos, uvec4(imageLoad(geom_facing_grid, grid_pos).r | facing_bits)); //store facing bits
3241		#else
3242				imageAtomicOr(geom_facing_grid, grid_pos, facing_bits); //store facing bits
3243		#endif
3244		
3245				if (length(emission) > 0.001) {
3246					float lumas[6];
3247					vec3 light_total = vec3(0);
3248		
3249					for (int i = 0; i < 6; i++) {
3250						float strength = max(0.0, dot(cam_normal, aniso_dir[i]));
3251						vec3 light = emission * strength;
3252						light_total += light;
3253						lumas[i] = max(light.r, max(light.g, light.b));
3254					}
3255		
3256					float luma_total = max(light_total.r, max(light_total.g, light_total.b));
3257		
3258					uint light_aniso = 0;
3259		
3260					for (int i = 0; i < 6; i++) {
3261						light_aniso |= min(31, uint((lumas[i] / luma_total) * 31.0)) << (i * 5);
3262					}
3263		
3264					//compress to RGBE9995 to save space
3265		
3266					const float pow2to9 = 512.0f;
3267					const float B = 15.0f;
3268					const float N = 9.0f;
3269					const float LN2 = 0.6931471805599453094172321215;
3270		
3271					float cRed = clamp(light_total.r, 0.0, 65408.0);
3272					float cGreen = clamp(light_total.g, 0.0, 65408.0);
3273					float cBlue = clamp(light_total.b, 0.0, 65408.0);
3274		
3275					float cMax = max(cRed, max(cGreen, cBlue));
3276		
3277					float expp = max(-B - 1.0f, floor(log(cMax) / LN2)) + 1.0f + B;
3278		
3279					float sMax = floor((cMax / pow(2.0f, expp - B - N)) + 0.5f);
3280		
3281					float exps = expp + 1.0f;
3282		
3283					if (0.0 <= sMax && sMax < pow2to9) {
3284						exps = expp;
3285					}
3286		
3287					float sRed = floor((cRed / pow(2.0f, exps - B - N)) + 0.5f);
3288					float sGreen = floor((cGreen / pow(2.0f, exps - B - N)) + 0.5f);
3289					float sBlue = floor((cBlue / pow(2.0f, exps - B - N)) + 0.5f);
3290					//store as 8985 to have 2 extra neighbor bits
3291					uint light_rgbe = ((uint(sRed) & 0x1FFu) >> 1) | ((uint(sGreen) & 0x1FFu) << 8) | (((uint(sBlue) & 0x1FFu) >> 1) << 17) | ((uint(exps) & 0x1Fu) << 25);
3292		
3293					imageStore(emission_grid, grid_pos, uvec4(light_rgbe));
3294					imageStore(emission_aniso_grid, grid_pos, uvec4(light_aniso));
3295				}
3296			}
3297		
3298		#endif
3299		
3300		#ifdef MODE_RENDER_MATERIAL
3301		
3302			albedo_output_buffer.rgb = albedo;
3303			albedo_output_buffer.a = alpha;
3304		
3305			normal_output_buffer.rgb = normal * 0.5 + 0.5;
3306			normal_output_buffer.a = 0.0;
3307			depth_output_buffer.r = -vertex.z;
3308		
3309			orm_output_buffer.r = ao;
3310			orm_output_buffer.g = roughness;
3311			orm_output_buffer.b = metallic;
3312			orm_output_buffer.a = sss_strength;
3313		
3314			emission_output_buffer.rgb = emission;
3315			emission_output_buffer.a = 0.0;
3316		#endif
3317		
3318		#ifdef MODE_RENDER_NORMAL_ROUGHNESS
3319			normal_roughness_output_buffer = vec4(normal * 0.5 + 0.5, roughness);
3320		
3321		#ifdef MODE_RENDER_VOXEL_GI
3322			if (bool(instances.data[instance_index].flags & INSTANCE_FLAGS_USE_VOXEL_GI)) { // process voxel_gi_instances
3323				uint index1 = instances.data[instance_index].gi_offset & 0xFFFF;
3324				uint index2 = instances.data[instance_index].gi_offset >> 16;
3325				voxel_gi_buffer.x = index1 & 0xFFu;
3326				voxel_gi_buffer.y = index2 & 0xFFu;
3327			} else {
3328				voxel_gi_buffer.x = 0xFF;
3329				voxel_gi_buffer.y = 0xFF;
3330			}
3331		#endif
3332		
3333		#endif //MODE_RENDER_NORMAL_ROUGHNESS
3334		
3335		//nothing happens, so a tree-ssa optimizer will result in no fragment shader :)
3336		#else
3337		
3338			// multiply by albedo
3339			diffuse_light *= albedo; // ambient must be multiplied by albedo at the end
3340		
3341			// apply direct light AO
3342			ao = unpackUnorm4x8(orms).x;
3343			specular_light *= ao;
3344			diffuse_light *= ao;
3345		
3346			// apply metallic
3347			metallic = unpackUnorm4x8(orms).z;
3348			diffuse_light *= 1.0 - metallic;
3349			ambient_light *= 1.0 - metallic;
3350		
3351		#ifndef FOG_DISABLED
3352			//restore fog
3353			fog = vec4(unpackHalf2x16(fog_rg), unpackHalf2x16(fog_ba));
3354		#endif //!FOG_DISABLED
3355		
3356		#ifdef MODE_SEPARATE_SPECULAR
3357		
3358		#ifdef MODE_UNSHADED
3359			diffuse_buffer = vec4(albedo.rgb, 0.0);
3360			specular_buffer = vec4(0.0);
3361		
3362		#else
3363		
3364		#ifdef SSS_MODE_SKIN
3365			sss_strength = -sss_strength;
3366		#endif
3367			diffuse_buffer = vec4(emission + diffuse_light + ambient_light, sss_strength);
3368			specular_buffer = vec4(specular_light, metallic);
3369		#endif
3370		
3371		#ifndef FOG_DISABLED
3372			diffuse_buffer.rgb = mix(diffuse_buffer.rgb, fog.rgb, fog.a);
3373			specular_buffer.rgb = mix(specular_buffer.rgb, vec3(0.0), fog.a);
3374		#endif //!FOG_DISABLED
3375		
3376		#else //MODE_SEPARATE_SPECULAR
3377		
3378			alpha *= scene_data.pass_alpha_multiplier;
3379		
3380		#ifdef MODE_UNSHADED
3381			frag_color = vec4(albedo, alpha);
3382		#else
3383			frag_color = vec4(emission + ambient_light + diffuse_light + specular_light, alpha);
3384		//frag_color = vec4(1.0);
3385		#endif //USE_NO_SHADING
3386		
3387		#ifndef FOG_DISABLED
3388			// Draw "fixed" fog before volumetric fog to ensure volumetric fog can appear in front of the sky.
3389			frag_color.rgb = mix(frag_color.rgb, fog.rgb, fog.a);
3390		#endif //!FOG_DISABLED
3391		
3392		#endif //MODE_SEPARATE_SPECULAR
3393		
3394		#endif //MODE_RENDER_DEPTH
3395		#ifdef MOTION_VECTORS
3396			vec2 position_clip = (screen_position.xy / screen_position.w) - scene_data.taa_jitter;
3397			vec2 prev_position_clip = (prev_screen_position.xy / prev_screen_position.w) - scene_data_block.prev_data.taa_jitter;
3398		
3399			vec2 position_uv = position_clip * vec2(0.5, 0.5);
3400			vec2 prev_position_uv = prev_position_clip * vec2(0.5, 0.5);
3401		
3402			motion_vector = prev_position_uv - position_uv;
3403		#endif
3404		}
3405		
3406		void main() {
3407		#ifdef MODE_DUAL_PARABOLOID
3408		
3409			if (dp_clip > 0.0)
3410				discard;
3411		#endif
3412		
3413			fragment_shader(scene_data_block.data);
3414		}
3415		
3416		
          RDShaderFile                                    RSRC