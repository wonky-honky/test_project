RSRC                    RDShaderFile            ��������                                                  resource_local_to_scene    resource_name    bytecode_vertex    bytecode_fragment    bytecode_tesselation_control     bytecode_tesselation_evaluation    bytecode_compute    compile_error_vertex    compile_error_fragment "   compile_error_tesselation_control %   compile_error_tesselation_evaluation    compile_error_compute    script 
   _versions    base_error           local://RDShaderSPIRV_6on1e ;         local://RDShaderFile_6re45 3�        RDShaderSPIRV          �Z  Failed parse:
ERROR: 0:15: '#include' : required extension not requested: GL_GOOGLE_include_directive
ERROR: 0:15: '#include' : must be followed by a header name 
ERROR: 0:15: '' : compilation terminated 
ERROR: 3 compilation errors.  No code generated.




Stage 'vertex' source code: 

1		
2		#version 450
3		
4		#
5		
6		/* Include our forward mobile UBOs definitions etc. */
7		
8		#define M_PI 3.14159265359
9		#define MAX_VIEWS 2
10		
11		#if defined(USE_MULTIVIEW) && defined(has_VK_KHR_multiview)
12		#extension GL_EXT_multiview : enable
13		#endif
14		
15		#include "../decal_data_inc.glsl"
16		#include "../scene_data_inc.glsl"
17		
18		#if !defined(MODE_RENDER_DEPTH) || defined(MODE_RENDER_MATERIAL) || defined(TANGENT_USED) || defined(NORMAL_MAP_USED) || defined(LIGHT_ANISOTROPY_USED)
19		#ifndef NORMAL_USED
20		#define NORMAL_USED
21		#endif
22		#endif
23		
24		#define USING_MOBILE_RENDERER
25		
26		layout(push_constant, std430) uniform DrawCall {
27			vec2 uv_offset;
28			uint instance_index;
29			uint pad;
30		}
31		draw_call;
32		
33		/* Set 0: Base Pass (never changes) */
34		
35		#include "../light_data_inc.glsl"
36		
37		#include "../samplers_inc.glsl"
38		
39		layout(set = 0, binding = 2) uniform sampler shadow_sampler;
40		
41		layout(set = 0, binding = 3) uniform sampler decal_sampler;
42		layout(set = 0, binding = 4) uniform sampler light_projector_sampler;
43		
44		#define INSTANCE_FLAGS_NON_UNIFORM_SCALE (1 << 4)
45		#define INSTANCE_FLAGS_USE_GI_BUFFERS (1 << 5)
46		#define INSTANCE_FLAGS_USE_SDFGI (1 << 6)
47		#define INSTANCE_FLAGS_USE_LIGHTMAP_CAPTURE (1 << 7)
48		#define INSTANCE_FLAGS_USE_LIGHTMAP (1 << 8)
49		#define INSTANCE_FLAGS_USE_SH_LIGHTMAP (1 << 9)
50		#define INSTANCE_FLAGS_USE_VOXEL_GI (1 << 10)
51		#define INSTANCE_FLAGS_PARTICLES (1 << 11)
52		#define INSTANCE_FLAGS_MULTIMESH (1 << 12)
53		#define INSTANCE_FLAGS_MULTIMESH_FORMAT_2D (1 << 13)
54		#define INSTANCE_FLAGS_MULTIMESH_HAS_COLOR (1 << 14)
55		#define INSTANCE_FLAGS_MULTIMESH_HAS_CUSTOM_DATA (1 << 15)
56		#define INSTANCE_FLAGS_PARTICLE_TRAIL_SHIFT 16
57		//3 bits of stride
58		#define INSTANCE_FLAGS_PARTICLE_TRAIL_MASK 0xFF
59		
60		layout(set = 0, binding = 5, std430) restrict readonly buffer OmniLights {
61			LightData data[];
62		}
63		omni_lights;
64		
65		layout(set = 0, binding = 6, std430) restrict readonly buffer SpotLights {
66			LightData data[];
67		}
68		spot_lights;
69		
70		layout(set = 0, binding = 7, std430) restrict readonly buffer ReflectionProbeData {
71			ReflectionData data[];
72		}
73		reflections;
74		
75		layout(set = 0, binding = 8, std140) uniform DirectionalLights {
76			DirectionalLightData data[MAX_DIRECTIONAL_LIGHT_DATA_STRUCTS];
77		}
78		directional_lights;
79		
80		#define LIGHTMAP_FLAG_USE_DIRECTION 1
81		#define LIGHTMAP_FLAG_USE_SPECULAR_DIRECTION 2
82		
83		struct Lightmap {
84			mediump mat3 normal_xform;
85			vec3 pad;
86			float exposure_normalization;
87		};
88		
89		layout(set = 0, binding = 9, std140) restrict readonly buffer Lightmaps {
90			Lightmap data[];
91		}
92		lightmaps;
93		
94		struct LightmapCapture {
95			mediump vec4 sh[9];
96		};
97		
98		layout(set = 0, binding = 10, std140) restrict readonly buffer LightmapCaptures {
99			LightmapCapture data[];
100		}
101		lightmap_captures;
102		
103		layout(set = 0, binding = 11) uniform mediump texture2D decal_atlas;
104		layout(set = 0, binding = 12) uniform mediump texture2D decal_atlas_srgb;
105		
106		layout(set = 0, binding = 13, std430) restrict readonly buffer Decals {
107			DecalData data[];
108		}
109		decals;
110		
111		layout(set = 0, binding = 14, std430) restrict readonly buffer GlobalShaderUniformData {
112			highp vec4 data[];
113		}
114		global_shader_uniforms;
115		
116		/* Set 1: Render Pass (changes per render pass) */
117		
118		layout(set = 1, binding = 0, std140) uniform SceneDataBlock {
119			SceneData data;
120			SceneData prev_data;
121		}
122		scene_data_block;
123		
124		struct InstanceData {
125			highp mat4 transform; // 64 - 64
126			uint flags; // 04 - 68
127			uint instance_uniforms_ofs; // Base offset in global buffer for instance variables.	// 04 - 72
128			uint gi_offset; // GI information when using lightmapping (VCT or lightmap index).    // 04 - 76
129			uint layer_mask; // 04 - 80
130			highp vec4 lightmap_uv_scale; // 16 - 96 Doubles as uv_offset when needed.
131		
132			uvec2 reflection_probes; // 08 - 104
133			uvec2 omni_lights; // 08 - 112
134			uvec2 spot_lights; // 08 - 120
135			uvec2 decals; // 08 - 128
136		
137			vec4 compressed_aabb_position_pad; // 16 - 144 // Only .xyz is used. .w is padding.
138			vec4 compressed_aabb_size_pad; // 16 - 160 // Only .xyz is used. .w is padding.
139			vec4 uv_scale; // 16 - 176
140		};
141		
142		layout(set = 1, binding = 1, std430) buffer restrict readonly InstanceDataBuffer {
143			InstanceData data[];
144		}
145		instances;
146		
147		#ifdef USE_RADIANCE_CUBEMAP_ARRAY
148		
149		layout(set = 1, binding = 2) uniform mediump textureCubeArray radiance_cubemap;
150		
151		#else
152		
153		layout(set = 1, binding = 2) uniform mediump textureCube radiance_cubemap;
154		
155		#endif
156		
157		layout(set = 1, binding = 3) uniform mediump textureCubeArray reflection_atlas;
158		
159		layout(set = 1, binding = 4) uniform highp texture2D shadow_atlas;
160		
161		layout(set = 1, binding = 5) uniform highp texture2D directional_shadow_atlas;
162		
163		// this needs to change to providing just the lightmap we're using..
164		layout(set = 1, binding = 6) uniform texture2DArray lightmap_textures[MAX_LIGHTMAP_TEXTURES];
165		
166		#ifdef USE_MULTIVIEW
167		layout(set = 1, binding = 9) uniform highp texture2DArray depth_buffer;
168		layout(set = 1, binding = 10) uniform mediump texture2DArray color_buffer;
169		#define multiviewSampler sampler2DArray
170		#else
171		layout(set = 1, binding = 9) uniform highp texture2D depth_buffer;
172		layout(set = 1, binding = 10) uniform mediump texture2D color_buffer;
173		#define multiviewSampler sampler2D
174		#endif // USE_MULTIVIEW
175		
176		/* Set 2 Skeleton & Instancing (can change per item) */
177		
178		layout(set = 2, binding = 0, std430) restrict readonly buffer Transforms {
179			highp vec4 data[];
180		}
181		transforms;
182		
183		/* Set 3 User Material */
184		
185		
186		#define SHADER_IS_SRGB false
187		
188		/* INPUT ATTRIBS */
189		
190		// Always contains vertex position in XYZ, can contain tangent angle in W.
191		layout(location = 0) in vec4 vertex_angle_attrib;
192		
193		//only for pure render depth when normal is not used
194		
195		#ifdef NORMAL_USED
196		// Contains Normal/Axis in RG, can contain tangent in BA.
197		layout(location = 1) in vec4 axis_tangent_attrib;
198		#endif
199		
200		// Location 2 is unused.
201		
202		#if defined(COLOR_USED)
203		layout(location = 3) in vec4 color_attrib;
204		#endif
205		
206		#ifdef UV_USED
207		layout(location = 4) in vec2 uv_attrib;
208		#endif
209		
210		#if defined(UV2_USED) || defined(USE_LIGHTMAP) || defined(MODE_RENDER_MATERIAL)
211		layout(location = 5) in vec2 uv2_attrib;
212		#endif // MODE_RENDER_MATERIAL
213		
214		#if defined(CUSTOM0_USED)
215		layout(location = 6) in vec4 custom0_attrib;
216		#endif
217		
218		#if defined(CUSTOM1_USED)
219		layout(location = 7) in vec4 custom1_attrib;
220		#endif
221		
222		#if defined(CUSTOM2_USED)
223		layout(location = 8) in vec4 custom2_attrib;
224		#endif
225		
226		#if defined(CUSTOM3_USED)
227		layout(location = 9) in vec4 custom3_attrib;
228		#endif
229		
230		#if defined(BONES_USED) || defined(USE_PARTICLE_TRAILS)
231		layout(location = 10) in uvec4 bone_attrib;
232		#endif
233		
234		#if defined(WEIGHTS_USED) || defined(USE_PARTICLE_TRAILS)
235		layout(location = 11) in vec4 weight_attrib;
236		#endif
237		
238		vec3 oct_to_vec3(vec2 e) {
239			vec3 v = vec3(e.xy, 1.0 - abs(e.x) - abs(e.y));
240			float t = max(-v.z, 0.0);
241			v.xy += t * -sign(v.xy);
242			return normalize(v);
243		}
244		
245		void axis_angle_to_tbn(vec3 axis, float angle, out vec3 tangent, out vec3 binormal, out vec3 normal) {
246			float c = cos(angle);
247			float s = sin(angle);
248			vec3 omc_axis = (1.0 - c) * axis;
249			vec3 s_axis = s * axis;
250			tangent = omc_axis.xxx * axis + vec3(c, -s_axis.z, s_axis.y);
251			binormal = omc_axis.yyy * axis + vec3(s_axis.z, c, -s_axis.x);
252			normal = omc_axis.zzz * axis + vec3(-s_axis.y, s_axis.x, c);
253		}
254		
255		/* Varyings */
256		
257		layout(location = 0) highp out vec3 vertex_interp;
258		
259		#ifdef NORMAL_USED
260		layout(location = 1) mediump out vec3 normal_interp;
261		#endif
262		
263		#if defined(COLOR_USED)
264		layout(location = 2) mediump out vec4 color_interp;
265		#endif
266		
267		#ifdef UV_USED
268		layout(location = 3) mediump out vec2 uv_interp;
269		#endif
270		
271		#if defined(UV2_USED) || defined(USE_LIGHTMAP)
272		layout(location = 4) mediump out vec2 uv2_interp;
273		#endif
274		
275		#if defined(TANGENT_USED) || defined(NORMAL_MAP_USED) || defined(LIGHT_ANISOTROPY_USED)
276		layout(location = 5) mediump out vec3 tangent_interp;
277		layout(location = 6) mediump out vec3 binormal_interp;
278		#endif
279		
280		#ifdef MATERIAL_UNIFORMS_USED
281		layout(set = MATERIAL_UNIFORM_SET, binding = 0, std140) uniform MaterialUniforms{
282		
283		#MATERIAL_UNIFORMS
284		
285		} material;
286		#endif
287		
288		#ifdef MODE_DUAL_PARABOLOID
289		
290		layout(location = 9) out highp float dp_clip;
291		
292		#endif
293		
294		#ifdef USE_MULTIVIEW
295		#ifdef has_VK_KHR_multiview
296		#define ViewIndex gl_ViewIndex
297		#else
298		// !BAS! This needs to become an input once we implement our fallback!
299		#define ViewIndex 0
300		#endif
301		vec3 multiview_uv(vec2 uv) {
302			return vec3(uv, ViewIndex);
303		}
304		#else
305		// Set to zero, not supported in non stereo
306		#define ViewIndex 0
307		vec2 multiview_uv(vec2 uv) {
308			return uv;
309		}
310		#endif //USE_MULTIVIEW
311		
312		invariant gl_Position;
313		
314		#GLOBALS
315		
316		#define scene_data scene_data_block.data
317		
318		#ifdef USE_DOUBLE_PRECISION
319		// Helper functions for emulating double precision when adding floats.
320		vec3 quick_two_sum(vec3 a, vec3 b, out vec3 out_p) {
321			vec3 s = a + b;
322			out_p = b - (s - a);
323			return s;
324		}
325		
326		vec3 two_sum(vec3 a, vec3 b, out vec3 out_p) {
327			vec3 s = a + b;
328			vec3 v = s - a;
329			out_p = (a - (s - v)) + (b - v);
330			return s;
331		}
332		
333		vec3 double_add_vec3(vec3 base_a, vec3 prec_a, vec3 base_b, vec3 prec_b, out vec3 out_precision) {
334			vec3 s, t, se, te;
335			s = two_sum(base_a, base_b, se);
336			t = two_sum(prec_a, prec_b, te);
337			se += t;
338			s = quick_two_sum(s, se, se);
339			se += te;
340			s = quick_two_sum(s, se, out_precision);
341			return s;
342		}
343		#endif
344		
345		void main() {
346			vec4 instance_custom = vec4(0.0);
347		#if defined(COLOR_USED)
348			color_interp = color_attrib;
349		#endif
350		
351			bool is_multimesh = bool(instances.data[draw_call.instance_index].flags & INSTANCE_FLAGS_MULTIMESH);
352		
353			mat4 model_matrix = instances.data[draw_call.instance_index].transform;
354			mat4 inv_view_matrix = scene_data.inv_view_matrix;
355		#ifdef USE_DOUBLE_PRECISION
356			vec3 model_precision = vec3(model_matrix[0][3], model_matrix[1][3], model_matrix[2][3]);
357			model_matrix[0][3] = 0.0;
358			model_matrix[1][3] = 0.0;
359			model_matrix[2][3] = 0.0;
360			vec3 view_precision = vec3(inv_view_matrix[0][3], inv_view_matrix[1][3], inv_view_matrix[2][3]);
361			inv_view_matrix[0][3] = 0.0;
362			inv_view_matrix[1][3] = 0.0;
363			inv_view_matrix[2][3] = 0.0;
364		#endif
365		
366			mat3 model_normal_matrix;
367			if (bool(instances.data[draw_call.instance_index].flags & INSTANCE_FLAGS_NON_UNIFORM_SCALE)) {
368				model_normal_matrix = transpose(inverse(mat3(model_matrix)));
369			} else {
370				model_normal_matrix = mat3(model_matrix);
371			}
372		
373			mat4 matrix;
374			mat4 read_model_matrix = model_matrix;
375		
376			if (is_multimesh) {
377				//multimesh, instances are for it
378		
379		#ifdef USE_PARTICLE_TRAILS
380				uint trail_size = (instances.data[draw_call.instance_index].flags >> INSTANCE_FLAGS_PARTICLE_TRAIL_SHIFT) & INSTANCE_FLAGS_PARTICLE_TRAIL_MASK;
381				uint stride = 3 + 1 + 1; //particles always uses this format
382		
383				uint offset = trail_size * stride * gl_InstanceIndex;
384		
385		#ifdef COLOR_USED
386				vec4 pcolor;
387		#endif
388				{
389					uint boffset = offset + bone_attrib.x * stride;
390					matrix = mat4(transforms.data[boffset + 0], transforms.data[boffset + 1], transforms.data[boffset + 2], vec4(0.0, 0.0, 0.0, 1.0)) * weight_attrib.x;
391		#ifdef COLOR_USED
392					pcolor = transforms.data[boffset + 3] * weight_attrib.x;
393		#endif
394				}
395				if (weight_attrib.y > 0.001) {
396					uint boffset = offset + bone_attrib.y * stride;
397					matrix += mat4(transforms.data[boffset + 0], transforms.data[boffset + 1], transforms.data[boffset + 2], vec4(0.0, 0.0, 0.0, 1.0)) * weight_attrib.y;
398		#ifdef COLOR_USED
399					pcolor += transforms.data[boffset + 3] * weight_attrib.y;
400		#endif
401				}
402				if (weight_attrib.z > 0.001) {
403					uint boffset = offset + bone_attrib.z * stride;
404					matrix += mat4(transforms.data[boffset + 0], transforms.data[boffset + 1], transforms.data[boffset + 2], vec4(0.0, 0.0, 0.0, 1.0)) * weight_attrib.z;
405		#ifdef COLOR_USED
406					pcolor += transforms.data[boffset + 3] * weight_attrib.z;
407		#endif
408				}
409				if (weight_attrib.w > 0.001) {
410					uint boffset = offset + bone_attrib.w * stride;
411					matrix += mat4(transforms.data[boffset + 0], transforms.data[boffset + 1], transforms.data[boffset + 2], vec4(0.0, 0.0, 0.0, 1.0)) * weight_attrib.w;
412		#ifdef COLOR_USED
413					pcolor += transforms.data[boffset + 3] * weight_attrib.w;
414		#endif
415				}
416		
417				instance_custom = transforms.data[offset + 4];
418		
419		#ifdef COLOR_USED
420				color_interp *= pcolor;
421		#endif
422		
423		#else
424				uint stride = 0;
425				{
426					//TODO implement a small lookup table for the stride
427					if (bool(instances.data[draw_call.instance_index].flags & INSTANCE_FLAGS_MULTIMESH_FORMAT_2D)) {
428						stride += 2;
429					} else {
430						stride += 3;
431					}
432					if (bool(instances.data[draw_call.instance_index].flags & INSTANCE_FLAGS_MULTIMESH_HAS_COLOR)) {
433						stride += 1;
434					}
435					if (bool(instances.data[draw_call.instance_index].flags & INSTANCE_FLAGS_MULTIMESH_HAS_CUSTOM_DATA)) {
436						stride += 1;
437					}
438				}
439		
440				uint offset = stride * gl_InstanceIndex;
441		
442				if (bool(instances.data[draw_call.instance_index].flags & INSTANCE_FLAGS_MULTIMESH_FORMAT_2D)) {
443					matrix = mat4(transforms.data[offset + 0], transforms.data[offset + 1], vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
444					offset += 2;
445				} else {
446					matrix = mat4(transforms.data[offset + 0], transforms.data[offset + 1], transforms.data[offset + 2], vec4(0.0, 0.0, 0.0, 1.0));
447					offset += 3;
448				}
449		
450				if (bool(instances.data[draw_call.instance_index].flags & INSTANCE_FLAGS_MULTIMESH_HAS_COLOR)) {
451		#ifdef COLOR_USED
452					color_interp *= transforms.data[offset];
453		#endif
454					offset += 1;
455				}
456		
457				if (bool(instances.data[draw_call.instance_index].flags & INSTANCE_FLAGS_MULTIMESH_HAS_CUSTOM_DATA)) {
458					instance_custom = transforms.data[offset];
459				}
460		
461		#endif
462				//transpose
463				matrix = transpose(matrix);
464		
465		#if !defined(USE_DOUBLE_PRECISION) || defined(SKIP_TRANSFORM_USED) || defined(VERTEX_WORLD_COORDS_USED) || defined(MODEL_MATRIX_USED)
466				// Normally we can bake the multimesh transform into the model matrix, but when using double precision
467				// we avoid baking it in so we can emulate high precision.
468				read_model_matrix = model_matrix * matrix;
469		#if !defined(USE_DOUBLE_PRECISION) || defined(SKIP_TRANSFORM_USED) || defined(VERTEX_WORLD_COORDS_USED)
470				model_matrix = read_model_matrix;
471		#endif // !defined(USE_DOUBLE_PRECISION) || defined(SKIP_TRANSFORM_USED) || defined(VERTEX_WORLD_COORDS_USED)
472		#endif // !defined(USE_DOUBLE_PRECISION) || defined(SKIP_TRANSFORM_USED) || defined(VERTEX_WORLD_COORDS_USED) || defined(MODEL_MATRIX_USED)
473				model_normal_matrix = model_normal_matrix * mat3(matrix);
474			}
475		
476			vec3 vertex = vertex_angle_attrib.xyz * instances.data[draw_call.instance_index].compressed_aabb_size_pad.xyz + instances.data[draw_call.instance_index].compressed_aabb_position_pad.xyz;
477		#ifdef NORMAL_USED
478			vec3 normal = oct_to_vec3(axis_tangent_attrib.xy * 2.0 - 1.0);
479		#endif
480		
481		#if defined(NORMAL_USED) || defined(TANGENT_USED) || defined(NORMAL_MAP_USED) || defined(LIGHT_ANISOTROPY_USED)
482		
483			vec3 binormal;
484			float binormal_sign;
485			vec3 tangent;
486			if (axis_tangent_attrib.z > 0.0 || axis_tangent_attrib.w < 1.0) {
487				// Uncompressed format.
488				vec2 signed_tangent_attrib = axis_tangent_attrib.zw * 2.0 - 1.0;
489				tangent = oct_to_vec3(vec2(signed_tangent_attrib.x, abs(signed_tangent_attrib.y) * 2.0 - 1.0));
490				binormal_sign = sign(signed_tangent_attrib.y);
491				binormal = normalize(cross(normal, tangent) * binormal_sign);
492			} else {
493				// Compressed format.
494				float angle = vertex_angle_attrib.w;
495				binormal_sign = angle > 0.5 ? 1.0 : -1.0; // 0.5 does not exist in UNORM16, so values are either greater or smaller.
496				angle = abs(angle * 2.0 - 1.0) * M_PI; // 0.5 is basically zero, allowing to encode both signs reliably.
497				vec3 axis = normal;
498				axis_angle_to_tbn(axis, angle, tangent, binormal, normal);
499				binormal *= binormal_sign;
500			}
501		#endif
502		
503		#ifdef UV_USED
504			uv_interp = uv_attrib;
505		#endif
506		
507		#if defined(UV2_USED) || defined(USE_LIGHTMAP)
508			uv2_interp = uv2_attrib;
509		#endif
510		
511			vec4 uv_scale = instances.data[draw_call.instance_index].uv_scale;
512		
513			if (uv_scale != vec4(0.0)) { // Compression enabled
514		#ifdef UV_USED
515				uv_interp = (uv_interp - 0.5) * uv_scale.xy;
516		#endif
517		#if defined(UV2_USED) || defined(USE_LIGHTMAP)
518				uv2_interp = (uv2_interp - 0.5) * uv_scale.zw;
519		#endif
520			}
521		
522		#ifdef OVERRIDE_POSITION
523			vec4 position;
524		#endif
525		
526		#ifdef USE_MULTIVIEW
527			mat4 projection_matrix = scene_data.projection_matrix_view[ViewIndex];
528			mat4 inv_projection_matrix = scene_data.inv_projection_matrix_view[ViewIndex];
529			vec3 eye_offset = scene_data.eye_offset[ViewIndex].xyz;
530		#else
531			mat4 projection_matrix = scene_data.projection_matrix;
532			mat4 inv_projection_matrix = scene_data.inv_projection_matrix;
533			vec3 eye_offset = vec3(0.0, 0.0, 0.0);
534		#endif //USE_MULTIVIEW
535		
536		//using world coordinates
537		#if !defined(SKIP_TRANSFORM_USED) && defined(VERTEX_WORLD_COORDS_USED)
538		
539			vertex = (model_matrix * vec4(vertex, 1.0)).xyz;
540		
541		#ifdef NORMAL_USED
542			normal = model_normal_matrix * normal;
543		#endif
544		
545		#if defined(TANGENT_USED) || defined(NORMAL_MAP_USED) || defined(LIGHT_ANISOTROPY_USED)
546		
547			tangent = model_normal_matrix * tangent;
548			binormal = model_normal_matrix * binormal;
549		
550		#endif
551		#endif
552		
553			float roughness = 1.0;
554		
555			mat4 modelview = scene_data.view_matrix * model_matrix;
556			mat3 modelview_normal = mat3(scene_data.view_matrix) * model_normal_matrix;
557			mat4 read_view_matrix = scene_data.view_matrix;
558			vec2 read_viewport_size = scene_data.viewport_size;
559		
560			{
561		#CODE : VERTEX
562			}
563		
564		// using local coordinates (default)
565		#if !defined(SKIP_TRANSFORM_USED) && !defined(VERTEX_WORLD_COORDS_USED)
566		
567		#ifdef USE_DOUBLE_PRECISION
568			// We separate the basis from the origin because the basis is fine with single point precision.
569			// Then we combine the translations from the model matrix and the view matrix using emulated doubles.
570			// We add the result to the vertex and ignore the final lost precision.
571			vec3 model_origin = model_matrix[3].xyz;
572			if (is_multimesh) {
573				vertex = mat3(matrix) * vertex;
574				model_origin = double_add_vec3(model_origin, model_precision, matrix[3].xyz, vec3(0.0), model_precision);
575			}
576			vertex = mat3(inv_view_matrix * modelview) * vertex;
577			vec3 temp_precision;
578			vertex += double_add_vec3(model_origin, model_precision, scene_data.inv_view_matrix[3].xyz, view_precision, temp_precision);
579			vertex = mat3(scene_data.view_matrix) * vertex;
580		#else
581			vertex = (modelview * vec4(vertex, 1.0)).xyz;
582		#endif
583		#ifdef NORMAL_USED
584			normal = modelview_normal * normal;
585		#endif
586		
587		#if defined(TANGENT_USED) || defined(NORMAL_MAP_USED) || defined(LIGHT_ANISOTROPY_USED)
588		
589			binormal = modelview_normal * binormal;
590			tangent = modelview_normal * tangent;
591		#endif
592		#endif // !defined(SKIP_TRANSFORM_USED) && !defined(VERTEX_WORLD_COORDS_USED)
593		
594		//using world coordinates
595		#if !defined(SKIP_TRANSFORM_USED) && defined(VERTEX_WORLD_COORDS_USED)
596		
597			vertex = (scene_data.view_matrix * vec4(vertex, 1.0)).xyz;
598		#ifdef NORMAL_USED
599			normal = (scene_data.view_matrix * vec4(normal, 0.0)).xyz;
600		#endif
601		
602		#if defined(TANGENT_USED) || defined(NORMAL_MAP_USED) || defined(LIGHT_ANISOTROPY_USED)
603			binormal = (scene_data.view_matrix * vec4(binormal, 0.0)).xyz;
604			tangent = (scene_data.view_matrix * vec4(tangent, 0.0)).xyz;
605		#endif
606		#endif
607		
608			vertex_interp = vertex;
609		#ifdef NORMAL_USED
610			normal_interp = normal;
611		#endif
612		
613		#if defined(TANGENT_USED) || defined(NORMAL_MAP_USED) || defined(LIGHT_ANISOTROPY_USED)
614			tangent_interp = tangent;
615			binormal_interp = binormal;
616		#endif
617		
618		#ifdef MODE_RENDER_DEPTH
619		
620		#ifdef MODE_DUAL_PARABOLOID
621		
622			vertex_interp.z *= scene_data.dual_paraboloid_side;
623		
624			dp_clip = vertex_interp.z; //this attempts to avoid noise caused by objects sent to the other parabolloid side due to bias
625		
626			//for dual paraboloid shadow mapping, this is the fastest but least correct way, as it curves straight edges
627		
628			vec3 vtx = vertex_interp;
629			float distance = length(vtx);
630			vtx = normalize(vtx);
631			vtx.xy /= 1.0 - vtx.z;
632			vtx.z = (distance / scene_data.z_far);
633			vtx.z = vtx.z * 2.0 - 1.0;
634			vertex_interp = vtx;
635		
636		#endif
637		
638		#endif //MODE_RENDER_DEPTH
639		
640		#ifdef OVERRIDE_POSITION
641			gl_Position = position;
642		#else
643			gl_Position = projection_matrix * vec4(vertex_interp, 1.0);
644		#endif // OVERRIDE_POSITION
645		
646		#ifdef MODE_RENDER_DEPTH
647			if (scene_data.pancake_shadows) {
648				if (gl_Position.z <= 0.00001) {
649					gl_Position.z = 0.00001;
650				}
651			}
652		#endif // MODE_RENDER_DEPTH
653		#ifdef MODE_RENDER_MATERIAL
654			if (scene_data.material_uv2_mode) {
655				gl_Position.xy = (uv2_attrib.xy + draw_call.uv_offset) * 2.0 - 1.0;
656				gl_Position.z = 0.00001;
657				gl_Position.w = 1.0;
658			}
659		#endif // MODE_RENDER_MATERIAL
660		}
661		
662		
       � Failed parse:
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
8		/* Specialization Constants */
9		
10		#if !defined(MODE_RENDER_DEPTH)
11		
12		#if !defined(MODE_UNSHADED)
13		
14		layout(constant_id = 0) const bool sc_use_light_projector = false;
15		layout(constant_id = 1) const bool sc_use_light_soft_shadows = false;
16		layout(constant_id = 2) const bool sc_use_directional_soft_shadows = false;
17		
18		layout(constant_id = 3) const uint sc_soft_shadow_samples = 4;
19		layout(constant_id = 4) const uint sc_penumbra_shadow_samples = 4;
20		
21		layout(constant_id = 5) const uint sc_directional_soft_shadow_samples = 4;
22		layout(constant_id = 6) const uint sc_directional_penumbra_shadow_samples = 4;
23		
24		layout(constant_id = 8) const bool sc_projector_use_mipmaps = true;
25		
26		layout(constant_id = 9) const bool sc_disable_omni_lights = false;
27		layout(constant_id = 10) const bool sc_disable_spot_lights = false;
28		layout(constant_id = 11) const bool sc_disable_reflection_probes = false;
29		layout(constant_id = 12) const bool sc_disable_directional_lights = false;
30		
31		#endif //!MODE_UNSHADED
32		
33		layout(constant_id = 7) const bool sc_decal_use_mipmaps = true;
34		layout(constant_id = 13) const bool sc_disable_decals = false;
35		layout(constant_id = 14) const bool sc_disable_fog = false;
36		
37		#endif //!MODE_RENDER_DEPTH
38		
39		layout(constant_id = 15) const float sc_luminance_multiplier = 2.0;
40		
41		/* Include our forward mobile UBOs definitions etc. */
42		
43		#define M_PI 3.14159265359
44		#define MAX_VIEWS 2
45		
46		#if defined(USE_MULTIVIEW) && defined(has_VK_KHR_multiview)
47		#extension GL_EXT_multiview : enable
48		#endif
49		
50		#include "../decal_data_inc.glsl"
51		#include "../scene_data_inc.glsl"
52		
53		#if !defined(MODE_RENDER_DEPTH) || defined(MODE_RENDER_MATERIAL) || defined(TANGENT_USED) || defined(NORMAL_MAP_USED) || defined(LIGHT_ANISOTROPY_USED)
54		#ifndef NORMAL_USED
55		#define NORMAL_USED
56		#endif
57		#endif
58		
59		#define USING_MOBILE_RENDERER
60		
61		layout(push_constant, std430) uniform DrawCall {
62			vec2 uv_offset;
63			uint instance_index;
64			uint pad;
65		}
66		draw_call;
67		
68		/* Set 0: Base Pass (never changes) */
69		
70		#include "../light_data_inc.glsl"
71		
72		#include "../samplers_inc.glsl"
73		
74		layout(set = 0, binding = 2) uniform sampler shadow_sampler;
75		
76		layout(set = 0, binding = 3) uniform sampler decal_sampler;
77		layout(set = 0, binding = 4) uniform sampler light_projector_sampler;
78		
79		#define INSTANCE_FLAGS_NON_UNIFORM_SCALE (1 << 4)
80		#define INSTANCE_FLAGS_USE_GI_BUFFERS (1 << 5)
81		#define INSTANCE_FLAGS_USE_SDFGI (1 << 6)
82		#define INSTANCE_FLAGS_USE_LIGHTMAP_CAPTURE (1 << 7)
83		#define INSTANCE_FLAGS_USE_LIGHTMAP (1 << 8)
84		#define INSTANCE_FLAGS_USE_SH_LIGHTMAP (1 << 9)
85		#define INSTANCE_FLAGS_USE_VOXEL_GI (1 << 10)
86		#define INSTANCE_FLAGS_PARTICLES (1 << 11)
87		#define INSTANCE_FLAGS_MULTIMESH (1 << 12)
88		#define INSTANCE_FLAGS_MULTIMESH_FORMAT_2D (1 << 13)
89		#define INSTANCE_FLAGS_MULTIMESH_HAS_COLOR (1 << 14)
90		#define INSTANCE_FLAGS_MULTIMESH_HAS_CUSTOM_DATA (1 << 15)
91		#define INSTANCE_FLAGS_PARTICLE_TRAIL_SHIFT 16
92		//3 bits of stride
93		#define INSTANCE_FLAGS_PARTICLE_TRAIL_MASK 0xFF
94		
95		layout(set = 0, binding = 5, std430) restrict readonly buffer OmniLights {
96			LightData data[];
97		}
98		omni_lights;
99		
100		layout(set = 0, binding = 6, std430) restrict readonly buffer SpotLights {
101			LightData data[];
102		}
103		spot_lights;
104		
105		layout(set = 0, binding = 7, std430) restrict readonly buffer ReflectionProbeData {
106			ReflectionData data[];
107		}
108		reflections;
109		
110		layout(set = 0, binding = 8, std140) uniform DirectionalLights {
111			DirectionalLightData data[MAX_DIRECTIONAL_LIGHT_DATA_STRUCTS];
112		}
113		directional_lights;
114		
115		#define LIGHTMAP_FLAG_USE_DIRECTION 1
116		#define LIGHTMAP_FLAG_USE_SPECULAR_DIRECTION 2
117		
118		struct Lightmap {
119			mediump mat3 normal_xform;
120			vec3 pad;
121			float exposure_normalization;
122		};
123		
124		layout(set = 0, binding = 9, std140) restrict readonly buffer Lightmaps {
125			Lightmap data[];
126		}
127		lightmaps;
128		
129		struct LightmapCapture {
130			mediump vec4 sh[9];
131		};
132		
133		layout(set = 0, binding = 10, std140) restrict readonly buffer LightmapCaptures {
134			LightmapCapture data[];
135		}
136		lightmap_captures;
137		
138		layout(set = 0, binding = 11) uniform mediump texture2D decal_atlas;
139		layout(set = 0, binding = 12) uniform mediump texture2D decal_atlas_srgb;
140		
141		layout(set = 0, binding = 13, std430) restrict readonly buffer Decals {
142			DecalData data[];
143		}
144		decals;
145		
146		layout(set = 0, binding = 14, std430) restrict readonly buffer GlobalShaderUniformData {
147			highp vec4 data[];
148		}
149		global_shader_uniforms;
150		
151		/* Set 1: Render Pass (changes per render pass) */
152		
153		layout(set = 1, binding = 0, std140) uniform SceneDataBlock {
154			SceneData data;
155			SceneData prev_data;
156		}
157		scene_data_block;
158		
159		struct InstanceData {
160			highp mat4 transform; // 64 - 64
161			uint flags; // 04 - 68
162			uint instance_uniforms_ofs; // Base offset in global buffer for instance variables.	// 04 - 72
163			uint gi_offset; // GI information when using lightmapping (VCT or lightmap index).    // 04 - 76
164			uint layer_mask; // 04 - 80
165			highp vec4 lightmap_uv_scale; // 16 - 96 Doubles as uv_offset when needed.
166		
167			uvec2 reflection_probes; // 08 - 104
168			uvec2 omni_lights; // 08 - 112
169			uvec2 spot_lights; // 08 - 120
170			uvec2 decals; // 08 - 128
171		
172			vec4 compressed_aabb_position_pad; // 16 - 144 // Only .xyz is used. .w is padding.
173			vec4 compressed_aabb_size_pad; // 16 - 160 // Only .xyz is used. .w is padding.
174			vec4 uv_scale; // 16 - 176
175		};
176		
177		layout(set = 1, binding = 1, std430) buffer restrict readonly InstanceDataBuffer {
178			InstanceData data[];
179		}
180		instances;
181		
182		#ifdef USE_RADIANCE_CUBEMAP_ARRAY
183		
184		layout(set = 1, binding = 2) uniform mediump textureCubeArray radiance_cubemap;
185		
186		#else
187		
188		layout(set = 1, binding = 2) uniform mediump textureCube radiance_cubemap;
189		
190		#endif
191		
192		layout(set = 1, binding = 3) uniform mediump textureCubeArray reflection_atlas;
193		
194		layout(set = 1, binding = 4) uniform highp texture2D shadow_atlas;
195		
196		layout(set = 1, binding = 5) uniform highp texture2D directional_shadow_atlas;
197		
198		// this needs to change to providing just the lightmap we're using..
199		layout(set = 1, binding = 6) uniform texture2DArray lightmap_textures[MAX_LIGHTMAP_TEXTURES];
200		
201		#ifdef USE_MULTIVIEW
202		layout(set = 1, binding = 9) uniform highp texture2DArray depth_buffer;
203		layout(set = 1, binding = 10) uniform mediump texture2DArray color_buffer;
204		#define multiviewSampler sampler2DArray
205		#else
206		layout(set = 1, binding = 9) uniform highp texture2D depth_buffer;
207		layout(set = 1, binding = 10) uniform mediump texture2D color_buffer;
208		#define multiviewSampler sampler2D
209		#endif // USE_MULTIVIEW
210		
211		/* Set 2 Skeleton & Instancing (can change per item) */
212		
213		layout(set = 2, binding = 0, std430) restrict readonly buffer Transforms {
214			highp vec4 data[];
215		}
216		transforms;
217		
218		/* Set 3 User Material */
219		
220		
221		/* Varyings */
222		
223		layout(location = 0) highp in vec3 vertex_interp;
224		
225		#ifdef NORMAL_USED
226		layout(location = 1) mediump in vec3 normal_interp;
227		#endif
228		
229		#if defined(COLOR_USED)
230		layout(location = 2) mediump in vec4 color_interp;
231		#endif
232		
233		#ifdef UV_USED
234		layout(location = 3) mediump in vec2 uv_interp;
235		#endif
236		
237		#if defined(UV2_USED) || defined(USE_LIGHTMAP)
238		layout(location = 4) mediump in vec2 uv2_interp;
239		#endif
240		
241		#if defined(TANGENT_USED) || defined(NORMAL_MAP_USED) || defined(LIGHT_ANISOTROPY_USED)
242		layout(location = 5) mediump in vec3 tangent_interp;
243		layout(location = 6) mediump in vec3 binormal_interp;
244		#endif
245		
246		#ifdef MODE_DUAL_PARABOLOID
247		
248		layout(location = 9) highp in float dp_clip;
249		
250		#endif
251		
252		#ifdef USE_MULTIVIEW
253		#ifdef has_VK_KHR_multiview
254		#define ViewIndex gl_ViewIndex
255		#else
256		// !BAS! This needs to become an input once we implement our fallback!
257		#define ViewIndex 0
258		#endif
259		vec3 multiview_uv(vec2 uv) {
260			return vec3(uv, ViewIndex);
261		}
262		#else
263		// Set to zero, not supported in non stereo
264		#define ViewIndex 0
265		vec2 multiview_uv(vec2 uv) {
266			return uv;
267		}
268		#endif //USE_MULTIVIEW
269		
270		//defines to keep compatibility with vertex
271		
272		#ifdef USE_MULTIVIEW
273		#define projection_matrix scene_data.projection_matrix_view[ViewIndex]
274		#define inv_projection_matrix scene_data.inv_projection_matrix_view[ViewIndex]
275		#else
276		#define projection_matrix scene_data.projection_matrix
277		#define inv_projection_matrix scene_data.inv_projection_matrix
278		#endif
279		
280		#if defined(ENABLE_SSS) && defined(ENABLE_TRANSMITTANCE)
281		//both required for transmittance to be enabled
282		#define LIGHT_TRANSMITTANCE_USED
283		#endif
284		
285		#ifdef MATERIAL_UNIFORMS_USED
286		layout(set = MATERIAL_UNIFORM_SET, binding = 0, std140) uniform MaterialUniforms{
287		
288		#MATERIAL_UNIFORMS
289		
290		} material;
291		#endif
292		
293		#GLOBALS
294		
295		/* clang-format on */
296		
297		#ifdef MODE_RENDER_DEPTH
298		
299		#ifdef MODE_RENDER_MATERIAL
300		
301		layout(location = 0) out vec4 albedo_output_buffer;
302		layout(location = 1) out vec4 normal_output_buffer;
303		layout(location = 2) out vec4 orm_output_buffer;
304		layout(location = 3) out vec4 emission_output_buffer;
305		layout(location = 4) out float depth_output_buffer;
306		
307		#endif // MODE_RENDER_MATERIAL
308		
309		#else // RENDER DEPTH
310		
311		#ifdef MODE_MULTIPLE_RENDER_TARGETS
312		
313		layout(location = 0) out vec4 diffuse_buffer; //diffuse (rgb) and roughness
314		layout(location = 1) out vec4 specular_buffer; //specular and SSS (subsurface scatter)
315		#else
316		
317		layout(location = 0) out mediump vec4 frag_color;
318		#endif // MODE_MULTIPLE_RENDER_TARGETS
319		
320		#endif // RENDER DEPTH
321		
322		
323		#ifdef ALPHA_HASH_USED
324		
325		float hash_2d(vec2 p) {
326			return fract(1.0e4 * sin(17.0 * p.x + 0.1 * p.y) *
327					(0.1 + abs(sin(13.0 * p.y + p.x))));
328		}
329		
330		float hash_3d(vec3 p) {
331			return hash_2d(vec2(hash_2d(p.xy), p.z));
332		}
333		
334		float compute_alpha_hash_threshold(vec3 pos, float hash_scale) {
335			vec3 dx = dFdx(pos);
336			vec3 dy = dFdy(pos);
337		
338			float delta_max_sqr = max(length(dx), length(dy));
339			float pix_scale = 1.0 / (hash_scale * delta_max_sqr);
340		
341			vec2 pix_scales =
342					vec2(exp2(floor(log2(pix_scale))), exp2(ceil(log2(pix_scale))));
343		
344			vec2 a_thresh = vec2(hash_3d(floor(pix_scales.x * pos.xyz)),
345					hash_3d(floor(pix_scales.y * pos.xyz)));
346		
347			float lerp_factor = fract(log2(pix_scale));
348		
349			float a_interp = (1.0 - lerp_factor) * a_thresh.x + lerp_factor * a_thresh.y;
350		
351			float min_lerp = min(lerp_factor, 1.0 - lerp_factor);
352		
353			vec3 cases = vec3(a_interp * a_interp / (2.0 * min_lerp * (1.0 - min_lerp)),
354					(a_interp - 0.5 * min_lerp) / (1.0 - min_lerp),
355					1.0 - ((1.0 - a_interp) * (1.0 - a_interp) / (2.0 * min_lerp * (1.0 - min_lerp))));
356		
357			float alpha_hash_threshold =
358					(a_interp < (1.0 - min_lerp)) ? ((a_interp < min_lerp) ? cases.x : cases.y) : cases.z;
359		
360			return clamp(alpha_hash_threshold, 0.00001, 1.0);
361		}
362		
363		#endif // ALPHA_HASH_USED
364		
365		#ifdef ALPHA_ANTIALIASING_EDGE_USED
366		
367		float calc_mip_level(vec2 texture_coord) {
368			vec2 dx = dFdx(texture_coord);
369			vec2 dy = dFdy(texture_coord);
370			float delta_max_sqr = max(dot(dx, dx), dot(dy, dy));
371			return max(0.0, 0.5 * log2(delta_max_sqr));
372		}
373		
374		float compute_alpha_antialiasing_edge(float input_alpha, vec2 texture_coord, float alpha_edge) {
375			input_alpha *= 1.0 + max(0, calc_mip_level(texture_coord)) * 0.25; // 0.25 mip scale, magic number
376			input_alpha = (input_alpha - alpha_edge) / max(fwidth(input_alpha), 0.0001) + 0.5;
377			return clamp(input_alpha, 0.0, 1.0);
378		}
379		
380		#endif // ALPHA_ANTIALIASING_USED
381		
382		
383		#if !defined(MODE_RENDER_DEPTH) && !defined(MODE_UNSHADED)
384		
385		// Default to SPECULAR_SCHLICK_GGX.
386		#if !defined(SPECULAR_DISABLED) && !defined(SPECULAR_SCHLICK_GGX) && !defined(SPECULAR_TOON)
387		#define SPECULAR_SCHLICK_GGX
388		#endif
389		
390		
391		// Functions related to lighting
392		
393		float D_GGX(float cos_theta_m, float alpha) {
394			float a = cos_theta_m * alpha;
395			float k = alpha / (1.0 - cos_theta_m * cos_theta_m + a * a);
396			return k * k * (1.0 / M_PI);
397		}
398		
399		// From Earl Hammon, Jr. "PBR Diffuse Lighting for GGX+Smith Microsurfaces" https://www.gdcvault.com/play/1024478/PBR-Diffuse-Lighting-for-GGX
400		float V_GGX(float NdotL, float NdotV, float alpha) {
401			return 0.5 / mix(2.0 * NdotL * NdotV, NdotL + NdotV, alpha);
402		}
403		
404		float D_GGX_anisotropic(float cos_theta_m, float alpha_x, float alpha_y, float cos_phi, float sin_phi) {
405			float alpha2 = alpha_x * alpha_y;
406			highp vec3 v = vec3(alpha_y * cos_phi, alpha_x * sin_phi, alpha2 * cos_theta_m);
407			highp float v2 = dot(v, v);
408			float w2 = alpha2 / v2;
409			float D = alpha2 * w2 * w2 * (1.0 / M_PI);
410			return D;
411		}
412		
413		float V_GGX_anisotropic(float alpha_x, float alpha_y, float TdotV, float TdotL, float BdotV, float BdotL, float NdotV, float NdotL) {
414			float Lambda_V = NdotL * length(vec3(alpha_x * TdotV, alpha_y * BdotV, NdotV));
415			float Lambda_L = NdotV * length(vec3(alpha_x * TdotL, alpha_y * BdotL, NdotL));
416			return 0.5 / (Lambda_V + Lambda_L);
417		}
418		
419		float SchlickFresnel(float u) {
420			float m = 1.0 - u;
421			float m2 = m * m;
422			return m2 * m2 * m; // pow(m,5)
423		}
424		
425		vec3 F0(float metallic, float specular, vec3 albedo) {
426			float dielectric = 0.16 * specular * specular;
427			// use albedo * metallic as colored specular reflectance at 0 angle for metallic materials;
428			// see https://google.github.io/filament/Filament.md.html
429			return mix(vec3(dielectric), albedo, vec3(metallic));
430		}
431		
432		void light_compute(vec3 N, vec3 L, vec3 V, float A, vec3 light_color, bool is_directional, float attenuation, vec3 f0, uint orms, float specular_amount, vec3 albedo, inout float alpha,
433		#ifdef LIGHT_BACKLIGHT_USED
434				vec3 backlight,
435		#endif
436		#ifdef LIGHT_TRANSMITTANCE_USED
437				vec4 transmittance_color,
438				float transmittance_depth,
439				float transmittance_boost,
440				float transmittance_z,
441		#endif
442		#ifdef LIGHT_RIM_USED
443				float rim, float rim_tint,
444		#endif
445		#ifdef LIGHT_CLEARCOAT_USED
446				float clearcoat, float clearcoat_roughness, vec3 vertex_normal,
447		#endif
448		#ifdef LIGHT_ANISOTROPY_USED
449				vec3 B, vec3 T, float anisotropy,
450		#endif
451				inout vec3 diffuse_light, inout vec3 specular_light) {
452		
453			vec4 orms_unpacked = unpackUnorm4x8(orms);
454		
455			float roughness = orms_unpacked.y;
456			float metallic = orms_unpacked.z;
457		
458		#if defined(LIGHT_CODE_USED)
459			// light is written by the light shader
460		
461			mat4 inv_view_matrix = scene_data_block.data.inv_view_matrix;
462		
463		#ifdef USING_MOBILE_RENDERER
464			mat4 read_model_matrix = instances.data[draw_call.instance_index].transform;
465		#else
466			mat4 read_model_matrix = instances.data[instance_index_interp].transform;
467		#endif
468		
469			mat4 read_view_matrix = scene_data_block.data.view_matrix;
470		
471		#undef projection_matrix
472		#define projection_matrix scene_data_block.data.projection_matrix
473		#undef inv_projection_matrix
474		#define inv_projection_matrix scene_data_block.data.inv_projection_matrix
475		
476			vec2 read_viewport_size = scene_data_block.data.viewport_size;
477		
478			vec3 normal = N;
479			vec3 light = L;
480			vec3 view = V;
481		
482		#CODE : LIGHT
483		
484		#else
485		
486			float NdotL = min(A + dot(N, L), 1.0);
487			float cNdotL = max(NdotL, 0.0); // clamped NdotL
488			float NdotV = dot(N, V);
489			float cNdotV = max(NdotV, 1e-4);
490		
491		#if defined(DIFFUSE_BURLEY) || defined(SPECULAR_SCHLICK_GGX) || defined(LIGHT_CLEARCOAT_USED)
492			vec3 H = normalize(V + L);
493		#endif
494		
495		#if defined(SPECULAR_SCHLICK_GGX)
496			float cNdotH = clamp(A + dot(N, H), 0.0, 1.0);
497		#endif
498		
499		#if defined(DIFFUSE_BURLEY) || defined(SPECULAR_SCHLICK_GGX) || defined(LIGHT_CLEARCOAT_USED)
500			float cLdotH = clamp(A + dot(L, H), 0.0, 1.0);
501		#endif
502		
503			if (metallic < 1.0) {
504				float diffuse_brdf_NL; // BRDF times N.L for calculating diffuse radiance
505		
506		#if defined(DIFFUSE_LAMBERT_WRAP)
507				// Energy conserving lambert wrap shader.
508				// https://web.archive.org/web/20210228210901/http://blog.stevemcauley.com/2011/12/03/energy-conserving-wrapped-diffuse/
509				diffuse_brdf_NL = max(0.0, (NdotL + roughness) / ((1.0 + roughness) * (1.0 + roughness))) * (1.0 / M_PI);
510		#elif defined(DIFFUSE_TOON)
511		
512				diffuse_brdf_NL = smoothstep(-roughness, max(roughness, 0.01), NdotL) * (1.0 / M_PI);
513		
514		#elif defined(DIFFUSE_BURLEY)
515		
516				{
517					float FD90_minus_1 = 2.0 * cLdotH * cLdotH * roughness - 0.5;
518					float FdV = 1.0 + FD90_minus_1 * SchlickFresnel(cNdotV);
519					float FdL = 1.0 + FD90_minus_1 * SchlickFresnel(cNdotL);
520					diffuse_brdf_NL = (1.0 / M_PI) * FdV * FdL * cNdotL;
521					/*
522					float energyBias = mix(roughness, 0.0, 0.5);
523					float energyFactor = mix(roughness, 1.0, 1.0 / 1.51);
524					float fd90 = energyBias + 2.0 * VoH * VoH * roughness;
525					float f0 = 1.0;
526					float lightScatter = f0 + (fd90 - f0) * pow(1.0 - cNdotL, 5.0);
527					float viewScatter = f0 + (fd90 - f0) * pow(1.0 - cNdotV, 5.0);
528		
529					diffuse_brdf_NL = lightScatter * viewScatter * energyFactor;
530					*/
531				}
532		#else
533				// lambert
534				diffuse_brdf_NL = cNdotL * (1.0 / M_PI);
535		#endif
536		
537				diffuse_light += light_color * diffuse_brdf_NL * attenuation;
538		
539		#if defined(LIGHT_BACKLIGHT_USED)
540				diffuse_light += light_color * (vec3(1.0 / M_PI) - diffuse_brdf_NL) * backlight * attenuation;
541		#endif
542		
543		#if defined(LIGHT_RIM_USED)
544				// Epsilon min to prevent pow(0, 0) singularity which results in undefined behavior.
545				float rim_light = pow(max(1e-4, 1.0 - cNdotV), max(0.0, (1.0 - roughness) * 16.0));
546				diffuse_light += rim_light * rim * mix(vec3(1.0), albedo, rim_tint) * light_color;
547		#endif
548		
549		#ifdef LIGHT_TRANSMITTANCE_USED
550		
551				{
552		#ifdef SSS_MODE_SKIN
553					float scale = 8.25 / transmittance_depth;
554					float d = scale * abs(transmittance_z);
555					float dd = -d * d;
556					vec3 profile = vec3(0.233, 0.455, 0.649) * exp(dd / 0.0064) +
557							vec3(0.1, 0.336, 0.344) * exp(dd / 0.0484) +
558							vec3(0.118, 0.198, 0.0) * exp(dd / 0.187) +
559							vec3(0.113, 0.007, 0.007) * exp(dd / 0.567) +
560							vec3(0.358, 0.004, 0.0) * exp(dd / 1.99) +
561							vec3(0.078, 0.0, 0.0) * exp(dd / 7.41);
562		
563					diffuse_light += profile * transmittance_color.a * light_color * clamp(transmittance_boost - NdotL, 0.0, 1.0) * (1.0 / M_PI);
564		#else
565		
566					float scale = 8.25 / transmittance_depth;
567					float d = scale * abs(transmittance_z);
568					float dd = -d * d;
569					diffuse_light += exp(dd) * transmittance_color.rgb * transmittance_color.a * light_color * clamp(transmittance_boost - NdotL, 0.0, 1.0) * (1.0 / M_PI);
570		#endif
571				}
572		#else
573		
574		#endif //LIGHT_TRANSMITTANCE_USED
575			}
576		
577			if (roughness > 0.0) { // FIXME: roughness == 0 should not disable specular light entirely
578		
579				// D
580		
581		#if defined(SPECULAR_TOON)
582		
583				vec3 R = normalize(-reflect(L, N));
584				float RdotV = dot(R, V);
585				float mid = 1.0 - roughness;
586				mid *= mid;
587				float intensity = smoothstep(mid - roughness * 0.5, mid + roughness * 0.5, RdotV) * mid;
588				diffuse_light += light_color * intensity * attenuation * specular_amount; // write to diffuse_light, as in toon shading you generally want no reflection
589		
590		#elif defined(SPECULAR_DISABLED)
591				// none..
592		
593		#elif defined(SPECULAR_SCHLICK_GGX)
594				// shlick+ggx as default
595				float alpha_ggx = roughness * roughness;
596		#if defined(LIGHT_ANISOTROPY_USED)
597		
598				float aspect = sqrt(1.0 - anisotropy * 0.9);
599				float ax = alpha_ggx / aspect;
600				float ay = alpha_ggx * aspect;
601				float XdotH = dot(T, H);
602				float YdotH = dot(B, H);
603				float D = D_GGX_anisotropic(cNdotH, ax, ay, XdotH, YdotH);
604				float G = V_GGX_anisotropic(ax, ay, dot(T, V), dot(T, L), dot(B, V), dot(B, L), cNdotV, cNdotL);
605		#else // LIGHT_ANISOTROPY_USED
606				float D = D_GGX(cNdotH, alpha_ggx);
607				float G = V_GGX(cNdotL, cNdotV, alpha_ggx);
608		#endif // LIGHT_ANISOTROPY_USED
609			   // F
610				float cLdotH5 = SchlickFresnel(cLdotH);
611				// Calculate Fresnel using specular occlusion term from Filament:
612				// https://google.github.io/filament/Filament.html#lighting/occlusion/specularocclusion
613				float f90 = clamp(dot(f0, vec3(50.0 * 0.33)), metallic, 1.0);
614				vec3 F = f0 + (f90 - f0) * cLdotH5;
615		
616				vec3 specular_brdf_NL = cNdotL * D * F * G;
617		
618				specular_light += specular_brdf_NL * light_color * attenuation * specular_amount;
619		#endif
620		
621		#if defined(LIGHT_CLEARCOAT_USED)
622				// Clearcoat ignores normal_map, use vertex normal instead
623				float ccNdotL = max(min(A + dot(vertex_normal, L), 1.0), 0.0);
624				float ccNdotH = clamp(A + dot(vertex_normal, H), 0.0, 1.0);
625				float ccNdotV = max(dot(vertex_normal, V), 1e-4);
626		
627		#if !defined(SPECULAR_SCHLICK_GGX)
628				float cLdotH5 = SchlickFresnel(cLdotH);
629		#endif
630				float Dr = D_GGX(ccNdotH, mix(0.001, 0.1, clearcoat_roughness));
631				float Gr = 0.25 / (cLdotH * cLdotH);
632				float Fr = mix(.04, 1.0, cLdotH5);
633				float clearcoat_specular_brdf_NL = clearcoat * Gr * Fr * Dr * cNdotL;
634		
635				specular_light += clearcoat_specular_brdf_NL * light_color * attenuation * specular_amount;
636				// TODO: Clearcoat adds light to the scene right now (it is non-energy conserving), both diffuse and specular need to be scaled by (1.0 - FR)
637				// but to do so we need to rearrange this entire function
638		#endif // LIGHT_CLEARCOAT_USED
639			}
640		
641		#ifdef USE_SHADOW_TO_OPACITY
642			alpha = min(alpha, clamp(1.0 - attenuation, 0.0, 1.0));
643		#endif
644		
645		#endif //defined(LIGHT_CODE_USED)
646		}
647		
648		#ifndef SHADOWS_DISABLED
649		
650		// Interleaved Gradient Noise
651		// https://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare
652		float quick_hash(vec2 pos) {
653			const vec3 magic = vec3(0.06711056f, 0.00583715f, 52.9829189f);
654			return fract(magic.z * fract(dot(pos, magic.xy)));
655		}
656		
657		float sample_directional_pcf_shadow(texture2D shadow, vec2 shadow_pixel_size, vec4 coord) {
658			vec2 pos = coord.xy;
659			float depth = coord.z;
660		
661			//if only one sample is taken, take it from the center
662			if (sc_directional_soft_shadow_samples == 0) {
663				return textureProj(sampler2DShadow(shadow, shadow_sampler), vec4(pos, depth, 1.0));
664			}
665		
666			mat2 disk_rotation;
667			{
668				float r = quick_hash(gl_FragCoord.xy) * 2.0 * M_PI;
669				float sr = sin(r);
670				float cr = cos(r);
671				disk_rotation = mat2(vec2(cr, -sr), vec2(sr, cr));
672			}
673		
674			float avg = 0.0;
675		
676			for (uint i = 0; i < sc_directional_soft_shadow_samples; i++) {
677				avg += textureProj(sampler2DShadow(shadow, shadow_sampler), vec4(pos + shadow_pixel_size * (disk_rotation * scene_data_block.data.directional_soft_shadow_kernel[i].xy), depth, 1.0));
678			}
679		
680			return avg * (1.0 / float(sc_directional_soft_shadow_samples));
681		}
682		
683		float sample_pcf_shadow(texture2D shadow, vec2 shadow_pixel_size, vec3 coord) {
684			vec2 pos = coord.xy;
685			float depth = coord.z;
686		
687			//if only one sample is taken, take it from the center
688			if (sc_soft_shadow_samples == 0) {
689				return textureProj(sampler2DShadow(shadow, shadow_sampler), vec4(pos, depth, 1.0));
690			}
691		
692			mat2 disk_rotation;
693			{
694				float r = quick_hash(gl_FragCoord.xy) * 2.0 * M_PI;
695				float sr = sin(r);
696				float cr = cos(r);
697				disk_rotation = mat2(vec2(cr, -sr), vec2(sr, cr));
698			}
699		
700			float avg = 0.0;
701		
702			for (uint i = 0; i < sc_soft_shadow_samples; i++) {
703				avg += textureProj(sampler2DShadow(shadow, shadow_sampler), vec4(pos + shadow_pixel_size * (disk_rotation * scene_data_block.data.soft_shadow_kernel[i].xy), depth, 1.0));
704			}
705		
706			return avg * (1.0 / float(sc_soft_shadow_samples));
707		}
708		
709		float sample_omni_pcf_shadow(texture2D shadow, float blur_scale, vec2 coord, vec4 uv_rect, vec2 flip_offset, float depth) {
710			//if only one sample is taken, take it from the center
711			if (sc_soft_shadow_samples == 0) {
712				vec2 pos = coord * 0.5 + 0.5;
713				pos = uv_rect.xy + pos * uv_rect.zw;
714				return textureProj(sampler2DShadow(shadow, shadow_sampler), vec4(pos, depth, 1.0));
715			}
716		
717			mat2 disk_rotation;
718			{
719				float r = quick_hash(gl_FragCoord.xy) * 2.0 * M_PI;
720				float sr = sin(r);
721				float cr = cos(r);
722				disk_rotation = mat2(vec2(cr, -sr), vec2(sr, cr));
723			}
724		
725			float avg = 0.0;
726			vec2 offset_scale = blur_scale * 2.0 * scene_data_block.data.shadow_atlas_pixel_size / uv_rect.zw;
727		
728			for (uint i = 0; i < sc_soft_shadow_samples; i++) {
729				vec2 offset = offset_scale * (disk_rotation * scene_data_block.data.soft_shadow_kernel[i].xy);
730				vec2 sample_coord = coord + offset;
731		
732				float sample_coord_length_sqaured = dot(sample_coord, sample_coord);
733				bool do_flip = sample_coord_length_sqaured > 1.0;
734		
735				if (do_flip) {
736					float len = sqrt(sample_coord_length_sqaured);
737					sample_coord = sample_coord * (2.0 / len - 1.0);
738				}
739		
740				sample_coord = sample_coord * 0.5 + 0.5;
741				sample_coord = uv_rect.xy + sample_coord * uv_rect.zw;
742		
743				if (do_flip) {
744					sample_coord += flip_offset;
745				}
746				avg += textureProj(sampler2DShadow(shadow, shadow_sampler), vec4(sample_coord, depth, 1.0));
747			}
748		
749			return avg * (1.0 / float(sc_soft_shadow_samples));
750		}
751		
752		float sample_directional_soft_shadow(texture2D shadow, vec3 pssm_coord, vec2 tex_scale) {
753			//find blocker
754			float blocker_count = 0.0;
755			float blocker_average = 0.0;
756		
757			mat2 disk_rotation;
758			{
759				float r = quick_hash(gl_FragCoord.xy) * 2.0 * M_PI;
760				float sr = sin(r);
761				float cr = cos(r);
762				disk_rotation = mat2(vec2(cr, -sr), vec2(sr, cr));
763			}
764		
765			for (uint i = 0; i < sc_directional_penumbra_shadow_samples; i++) {
766				vec2 suv = pssm_coord.xy + (disk_rotation * scene_data_block.data.directional_penumbra_shadow_kernel[i].xy) * tex_scale;
767				float d = textureLod(sampler2D(shadow, SAMPLER_LINEAR_CLAMP), suv, 0.0).r;
768				if (d < pssm_coord.z) {
769					blocker_average += d;
770					blocker_count += 1.0;
771				}
772			}
773		
774			if (blocker_count > 0.0) {
775				//blockers found, do soft shadow
776				blocker_average /= blocker_count;
777				float penumbra = (pssm_coord.z - blocker_average) / blocker_average;
778				tex_scale *= penumbra;
779		
780				float s = 0.0;
781				for (uint i = 0; i < sc_directional_penumbra_shadow_samples; i++) {
782					vec2 suv = pssm_coord.xy + (disk_rotation * scene_data_block.data.directional_penumbra_shadow_kernel[i].xy) * tex_scale;
783					s += textureProj(sampler2DShadow(shadow, shadow_sampler), vec4(suv, pssm_coord.z, 1.0));
784				}
785		
786				return s / float(sc_directional_penumbra_shadow_samples);
787		
788			} else {
789				//no blockers found, so no shadow
790				return 1.0;
791			}
792		}
793		
794		#endif // SHADOWS_DISABLED
795		
796		float get_omni_attenuation(float distance, float inv_range, float decay) {
797			float nd = distance * inv_range;
798			nd *= nd;
799			nd *= nd; // nd^4
800			nd = max(1.0 - nd, 0.0);
801			nd *= nd; // nd^2
802			return nd * pow(max(distance, 0.0001), -decay);
803		}
804		
805		float light_process_omni_shadow(uint idx, vec3 vertex, vec3 normal) {
806		#ifndef SHADOWS_DISABLED
807			if (omni_lights.data[idx].shadow_opacity > 0.001) {
808				// there is a shadowmap
809				vec2 texel_size = scene_data_block.data.shadow_atlas_pixel_size;
810				vec4 base_uv_rect = omni_lights.data[idx].atlas_rect;
811				base_uv_rect.xy += texel_size;
812				base_uv_rect.zw -= texel_size * 2.0;
813		
814				// Omni lights use direction.xy to store to store the offset between the two paraboloid regions
815				vec2 flip_offset = omni_lights.data[idx].direction.xy;
816		
817				vec3 local_vert = (omni_lights.data[idx].shadow_matrix * vec4(vertex, 1.0)).xyz;
818		
819				float shadow_len = length(local_vert); //need to remember shadow len from here
820				vec3 shadow_dir = normalize(local_vert);
821		
822				vec3 local_normal = normalize(mat3(omni_lights.data[idx].shadow_matrix) * normal);
823				vec3 normal_bias = local_normal * omni_lights.data[idx].shadow_normal_bias * (1.0 - abs(dot(local_normal, shadow_dir)));
824		
825				float shadow;
826		
827				if (sc_use_light_soft_shadows && omni_lights.data[idx].soft_shadow_size > 0.0) {
828					//soft shadow
829		
830					//find blocker
831		
832					float blocker_count = 0.0;
833					float blocker_average = 0.0;
834		
835					mat2 disk_rotation;
836					{
837						float r = quick_hash(gl_FragCoord.xy) * 2.0 * M_PI;
838						float sr = sin(r);
839						float cr = cos(r);
840						disk_rotation = mat2(vec2(cr, -sr), vec2(sr, cr));
841					}
842		
843					vec3 basis_normal = shadow_dir;
844					vec3 v0 = abs(basis_normal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
845					vec3 tangent = normalize(cross(v0, basis_normal));
846					vec3 bitangent = normalize(cross(tangent, basis_normal));
847					float z_norm = shadow_len * omni_lights.data[idx].inv_radius;
848		
849					tangent *= omni_lights.data[idx].soft_shadow_size * omni_lights.data[idx].soft_shadow_scale;
850					bitangent *= omni_lights.data[idx].soft_shadow_size * omni_lights.data[idx].soft_shadow_scale;
851		
852					for (uint i = 0; i < sc_penumbra_shadow_samples; i++) {
853						vec2 disk = disk_rotation * scene_data_block.data.penumbra_shadow_kernel[i].xy;
854		
855						vec3 pos = local_vert + tangent * disk.x + bitangent * disk.y;
856		
857						pos = normalize(pos);
858		
859						vec4 uv_rect = base_uv_rect;
860		
861						if (pos.z >= 0.0) {
862							uv_rect.xy += flip_offset;
863						}
864		
865						pos.z = 1.0 + abs(pos.z);
866						pos.xy /= pos.z;
867		
868						pos.xy = pos.xy * 0.5 + 0.5;
869						pos.xy = uv_rect.xy + pos.xy * uv_rect.zw;
870		
871						float d = textureLod(sampler2D(shadow_atlas, SAMPLER_LINEAR_CLAMP), pos.xy, 0.0).r;
872						if (d < z_norm) {
873							blocker_average += d;
874							blocker_count += 1.0;
875						}
876					}
877		
878					if (blocker_count > 0.0) {
879						//blockers found, do soft shadow
880						blocker_average /= blocker_count;
881						float penumbra = (z_norm - blocker_average) / blocker_average;
882						tangent *= penumbra;
883						bitangent *= penumbra;
884		
885						z_norm -= omni_lights.data[idx].inv_radius * omni_lights.data[idx].shadow_bias;
886		
887						shadow = 0.0;
888						for (uint i = 0; i < sc_penumbra_shadow_samples; i++) {
889							vec2 disk = disk_rotation * scene_data_block.data.penumbra_shadow_kernel[i].xy;
890							vec3 pos = local_vert + tangent * disk.x + bitangent * disk.y;
891		
892							pos = normalize(pos);
893							pos = normalize(pos + normal_bias);
894		
895							vec4 uv_rect = base_uv_rect;
896		
897							if (pos.z >= 0.0) {
898								uv_rect.xy += flip_offset;
899							}
900		
901							pos.z = 1.0 + abs(pos.z);
902							pos.xy /= pos.z;
903		
904							pos.xy = pos.xy * 0.5 + 0.5;
905							pos.xy = uv_rect.xy + pos.xy * uv_rect.zw;
906							shadow += textureProj(sampler2DShadow(shadow_atlas, shadow_sampler), vec4(pos.xy, z_norm, 1.0));
907						}
908		
909						shadow /= float(sc_penumbra_shadow_samples);
910						shadow = mix(1.0, shadow, omni_lights.data[idx].shadow_opacity);
911		
912					} else {
913						//no blockers found, so no shadow
914						shadow = 1.0;
915					}
916				} else {
917					vec4 uv_rect = base_uv_rect;
918		
919					vec3 shadow_sample = normalize(shadow_dir + normal_bias);
920					if (shadow_sample.z >= 0.0) {
921						uv_rect.xy += flip_offset;
922						flip_offset *= -1.0;
923					}
924		
925					shadow_sample.z = 1.0 + abs(shadow_sample.z);
926					vec2 pos = shadow_sample.xy / shadow_sample.z;
927					float depth = shadow_len - omni_lights.data[idx].shadow_bias;
928					depth *= omni_lights.data[idx].inv_radius;
929					shadow = mix(1.0, sample_omni_pcf_shadow(shadow_atlas, omni_lights.data[idx].soft_shadow_scale / shadow_sample.z, pos, uv_rect, flip_offset, depth), omni_lights.data[idx].shadow_opacity);
930				}
931		
932				return shadow;
933			}
934		#endif
935		
936			return 1.0;
937		}
938		
939		void light_process_omni(uint idx, vec3 vertex, vec3 eye_vec, vec3 normal, vec3 vertex_ddx, vec3 vertex_ddy, vec3 f0, uint orms, float shadow, vec3 albedo, inout float alpha,
940		#ifdef LIGHT_BACKLIGHT_USED
941				vec3 backlight,
942		#endif
943		#ifdef LIGHT_TRANSMITTANCE_USED
944				vec4 transmittance_color,
945				float transmittance_depth,
946				float transmittance_boost,
947		#endif
948		#ifdef LIGHT_RIM_USED
949				float rim, float rim_tint,
950		#endif
951		#ifdef LIGHT_CLEARCOAT_USED
952				float clearcoat, float clearcoat_roughness, vec3 vertex_normal,
953		#endif
954		#ifdef LIGHT_ANISOTROPY_USED
955				vec3 binormal, vec3 tangent, float anisotropy,
956		#endif
957				inout vec3 diffuse_light, inout vec3 specular_light) {
958			vec3 light_rel_vec = omni_lights.data[idx].position - vertex;
959			float light_length = length(light_rel_vec);
960			float omni_attenuation = get_omni_attenuation(light_length, omni_lights.data[idx].inv_radius, omni_lights.data[idx].attenuation);
961			float light_attenuation = omni_attenuation;
962			vec3 color = omni_lights.data[idx].color;
963		
964			float size_A = 0.0;
965		
966			if (sc_use_light_soft_shadows && omni_lights.data[idx].size > 0.0) {
967				float t = omni_lights.data[idx].size / max(0.001, light_length);
968				size_A = max(0.0, 1.0 - 1 / sqrt(1 + t * t));
969			}
970		
971		#ifdef LIGHT_TRANSMITTANCE_USED
972			float transmittance_z = transmittance_depth; //no transmittance by default
973			transmittance_color.a *= light_attenuation;
974			{
975				vec4 clamp_rect = omni_lights.data[idx].atlas_rect;
976		
977				//redo shadowmapping, but shrink the model a bit to avoid artifacts
978				vec4 splane = (omni_lights.data[idx].shadow_matrix * vec4(vertex - normalize(normal_interp) * omni_lights.data[idx].transmittance_bias, 1.0));
979		
980				float shadow_len = length(splane.xyz);
981				splane.xyz = normalize(splane.xyz);
982		
983				if (splane.z >= 0.0) {
984					splane.z += 1.0;
985					clamp_rect.y += clamp_rect.w;
986				} else {
987					splane.z = 1.0 - splane.z;
988				}
989		
990				splane.xy /= splane.z;
991		
992				splane.xy = splane.xy * 0.5 + 0.5;
993				splane.z = shadow_len * omni_lights.data[idx].inv_radius;
994				splane.xy = clamp_rect.xy + splane.xy * clamp_rect.zw;
995				//		splane.xy = clamp(splane.xy,clamp_rect.xy + scene_data_block.data.shadow_atlas_pixel_size,clamp_rect.xy + clamp_rect.zw - scene_data_block.data.shadow_atlas_pixel_size );
996				splane.w = 1.0; //needed? i think it should be 1 already
997		
998				float shadow_z = textureLod(sampler2D(shadow_atlas, SAMPLER_LINEAR_CLAMP), splane.xy, 0.0).r;
999				transmittance_z = (splane.z - shadow_z) / omni_lights.data[idx].inv_radius;
1000			}
1001		#endif
1002		
1003			if (sc_use_light_projector && omni_lights.data[idx].projector_rect != vec4(0.0)) {
1004				vec3 local_v = (omni_lights.data[idx].shadow_matrix * vec4(vertex, 1.0)).xyz;
1005				local_v = normalize(local_v);
1006		
1007				vec4 atlas_rect = omni_lights.data[idx].projector_rect;
1008		
1009				if (local_v.z >= 0.0) {
1010					atlas_rect.y += atlas_rect.w;
1011				}
1012		
1013				local_v.z = 1.0 + abs(local_v.z);
1014		
1015				local_v.xy /= local_v.z;
1016				local_v.xy = local_v.xy * 0.5 + 0.5;
1017				vec2 proj_uv = local_v.xy * atlas_rect.zw;
1018		
1019				if (sc_projector_use_mipmaps) {
1020					vec2 proj_uv_ddx;
1021					vec2 proj_uv_ddy;
1022					{
1023						vec3 local_v_ddx = (omni_lights.data[idx].shadow_matrix * vec4(vertex + vertex_ddx, 1.0)).xyz;
1024						local_v_ddx = normalize(local_v_ddx);
1025		
1026						if (local_v_ddx.z >= 0.0) {
1027							local_v_ddx.z += 1.0;
1028						} else {
1029							local_v_ddx.z = 1.0 - local_v_ddx.z;
1030						}
1031		
1032						local_v_ddx.xy /= local_v_ddx.z;
1033						local_v_ddx.xy = local_v_ddx.xy * 0.5 + 0.5;
1034		
1035						proj_uv_ddx = local_v_ddx.xy * atlas_rect.zw - proj_uv;
1036		
1037						vec3 local_v_ddy = (omni_lights.data[idx].shadow_matrix * vec4(vertex + vertex_ddy, 1.0)).xyz;
1038						local_v_ddy = normalize(local_v_ddy);
1039		
1040						if (local_v_ddy.z >= 0.0) {
1041							local_v_ddy.z += 1.0;
1042						} else {
1043							local_v_ddy.z = 1.0 - local_v_ddy.z;
1044						}
1045		
1046						local_v_ddy.xy /= local_v_ddy.z;
1047						local_v_ddy.xy = local_v_ddy.xy * 0.5 + 0.5;
1048		
1049						proj_uv_ddy = local_v_ddy.xy * atlas_rect.zw - proj_uv;
1050					}
1051		
1052					vec4 proj = textureGrad(sampler2D(decal_atlas_srgb, light_projector_sampler), proj_uv + atlas_rect.xy, proj_uv_ddx, proj_uv_ddy);
1053					color *= proj.rgb * proj.a;
1054				} else {
1055					vec4 proj = textureLod(sampler2D(decal_atlas_srgb, light_projector_sampler), proj_uv + atlas_rect.xy, 0.0);
1056					color *= proj.rgb * proj.a;
1057				}
1058			}
1059		
1060			light_attenuation *= shadow;
1061		
1062			light_compute(normal, normalize(light_rel_vec), eye_vec, size_A, color, false, light_attenuation, f0, orms, omni_lights.data[idx].specular_amount, albedo, alpha,
1063		#ifdef LIGHT_BACKLIGHT_USED
1064					backlight,
1065		#endif
1066		#ifdef LIGHT_TRANSMITTANCE_USED
1067					transmittance_color,
1068					transmittance_depth,
1069					transmittance_boost,
1070					transmittance_z,
1071		#endif
1072		#ifdef LIGHT_RIM_USED
1073					rim * omni_attenuation, rim_tint,
1074		#endif
1075		#ifdef LIGHT_CLEARCOAT_USED
1076					clearcoat, clearcoat_roughness, vertex_normal,
1077		#endif
1078		#ifdef LIGHT_ANISOTROPY_USED
1079					binormal, tangent, anisotropy,
1080		#endif
1081					diffuse_light,
1082					specular_light);
1083		}
1084		
1085		float light_process_spot_shadow(uint idx, vec3 vertex, vec3 normal) {
1086		#ifndef SHADOWS_DISABLED
1087			if (spot_lights.data[idx].shadow_opacity > 0.001) {
1088				vec3 light_rel_vec = spot_lights.data[idx].position - vertex;
1089				float light_length = length(light_rel_vec);
1090				vec3 spot_dir = spot_lights.data[idx].direction;
1091		
1092				vec3 shadow_dir = light_rel_vec / light_length;
1093				vec3 normal_bias = normal * light_length * spot_lights.data[idx].shadow_normal_bias * (1.0 - abs(dot(normal, shadow_dir)));
1094		
1095				//there is a shadowmap
1096				vec4 v = vec4(vertex + normal_bias, 1.0);
1097		
1098				vec4 splane = (spot_lights.data[idx].shadow_matrix * v);
1099				splane.z -= spot_lights.data[idx].shadow_bias / (light_length * spot_lights.data[idx].inv_radius);
1100				splane /= splane.w;
1101		
1102				float shadow;
1103				if (sc_use_light_soft_shadows && spot_lights.data[idx].soft_shadow_size > 0.0) {
1104					//soft shadow
1105		
1106					//find blocker
1107					float z_norm = dot(spot_dir, -light_rel_vec) * spot_lights.data[idx].inv_radius;
1108		
1109					vec2 shadow_uv = splane.xy * spot_lights.data[idx].atlas_rect.zw + spot_lights.data[idx].atlas_rect.xy;
1110		
1111					float blocker_count = 0.0;
1112					float blocker_average = 0.0;
1113		
1114					mat2 disk_rotation;
1115					{
1116						float r = quick_hash(gl_FragCoord.xy) * 2.0 * M_PI;
1117						float sr = sin(r);
1118						float cr = cos(r);
1119						disk_rotation = mat2(vec2(cr, -sr), vec2(sr, cr));
1120					}
1121		
1122					float uv_size = spot_lights.data[idx].soft_shadow_size * z_norm * spot_lights.data[idx].soft_shadow_scale;
1123					vec2 clamp_max = spot_lights.data[idx].atlas_rect.xy + spot_lights.data[idx].atlas_rect.zw;
1124					for (uint i = 0; i < sc_penumbra_shadow_samples; i++) {
1125						vec2 suv = shadow_uv + (disk_rotation * scene_data_block.data.penumbra_shadow_kernel[i].xy) * uv_size;
1126						suv = clamp(suv, spot_lights.data[idx].atlas_rect.xy, clamp_max);
1127						float d = textureLod(sampler2D(shadow_atlas, SAMPLER_LINEAR_CLAMP), suv, 0.0).r;
1128						if (d < splane.z) {
1129							blocker_average += d;
1130							blocker_count += 1.0;
1131						}
1132					}
1133		
1134					if (blocker_count > 0.0) {
1135						//blockers found, do soft shadow
1136						blocker_average /= blocker_count;
1137						float penumbra = (z_norm - blocker_average) / blocker_average;
1138						uv_size *= penumbra;
1139		
1140						shadow = 0.0;
1141						for (uint i = 0; i < sc_penumbra_shadow_samples; i++) {
1142							vec2 suv = shadow_uv + (disk_rotation * scene_data_block.data.penumbra_shadow_kernel[i].xy) * uv_size;
1143							suv = clamp(suv, spot_lights.data[idx].atlas_rect.xy, clamp_max);
1144							shadow += textureProj(sampler2DShadow(shadow_atlas, shadow_sampler), vec4(suv, splane.z, 1.0));
1145						}
1146		
1147						shadow /= float(sc_penumbra_shadow_samples);
1148						shadow = mix(1.0, shadow, spot_lights.data[idx].shadow_opacity);
1149		
1150					} else {
1151						//no blockers found, so no shadow
1152						shadow = 1.0;
1153					}
1154				} else {
1155					//hard shadow
1156					vec3 shadow_uv = vec3(splane.xy * spot_lights.data[idx].atlas_rect.zw + spot_lights.data[idx].atlas_rect.xy, splane.z);
1157					shadow = mix(1.0, sample_pcf_shadow(shadow_atlas, spot_lights.data[idx].soft_shadow_scale * scene_data_block.data.shadow_atlas_pixel_size, shadow_uv), spot_lights.data[idx].shadow_opacity);
1158				}
1159		
1160				return shadow;
1161			}
1162		
1163		#endif // SHADOWS_DISABLED
1164		
1165			return 1.0;
1166		}
1167		
1168		vec2 normal_to_panorama(vec3 n) {
1169			n = normalize(n);
1170			vec2 panorama_coords = vec2(atan(n.x, n.z), acos(-n.y));
1171		
1172			if (panorama_coords.x < 0.0) {
1173				panorama_coords.x += M_PI * 2.0;
1174			}
1175		
1176			panorama_coords /= vec2(M_PI * 2.0, M_PI);
1177			return panorama_coords;
1178		}
1179		
1180		void light_process_spot(uint idx, vec3 vertex, vec3 eye_vec, vec3 normal, vec3 vertex_ddx, vec3 vertex_ddy, vec3 f0, uint orms, float shadow, vec3 albedo, inout float alpha,
1181		#ifdef LIGHT_BACKLIGHT_USED
1182				vec3 backlight,
1183		#endif
1184		#ifdef LIGHT_TRANSMITTANCE_USED
1185				vec4 transmittance_color,
1186				float transmittance_depth,
1187				float transmittance_boost,
1188		#endif
1189		#ifdef LIGHT_RIM_USED
1190				float rim, float rim_tint,
1191		#endif
1192		#ifdef LIGHT_CLEARCOAT_USED
1193				float clearcoat, float clearcoat_roughness, vec3 vertex_normal,
1194		#endif
1195		#ifdef LIGHT_ANISOTROPY_USED
1196				vec3 binormal, vec3 tangent, float anisotropy,
1197		#endif
1198				inout vec3 diffuse_light,
1199				inout vec3 specular_light) {
1200			vec3 light_rel_vec = spot_lights.data[idx].position - vertex;
1201			float light_length = length(light_rel_vec);
1202			float spot_attenuation = get_omni_attenuation(light_length, spot_lights.data[idx].inv_radius, spot_lights.data[idx].attenuation);
1203			vec3 spot_dir = spot_lights.data[idx].direction;
1204		
1205			// This conversion to a highp float is crucial to prevent light leaking
1206			// due to precision errors in the following calculations (cone angle is mediump).
1207			highp float cone_angle = spot_lights.data[idx].cone_angle;
1208			float scos = max(dot(-normalize(light_rel_vec), spot_dir), cone_angle);
1209			float spot_rim = max(0.0001, (1.0 - scos) / (1.0 - cone_angle));
1210		
1211			spot_attenuation *= 1.0 - pow(spot_rim, spot_lights.data[idx].cone_attenuation);
1212			float light_attenuation = spot_attenuation;
1213			vec3 color = spot_lights.data[idx].color;
1214			float specular_amount = spot_lights.data[idx].specular_amount;
1215		
1216			float size_A = 0.0;
1217		
1218			if (sc_use_light_soft_shadows && spot_lights.data[idx].size > 0.0) {
1219				float t = spot_lights.data[idx].size / max(0.001, light_length);
1220				size_A = max(0.0, 1.0 - 1 / sqrt(1 + t * t));
1221			}
1222		
1223		#ifdef LIGHT_TRANSMITTANCE_USED
1224			float transmittance_z = transmittance_depth;
1225			transmittance_color.a *= light_attenuation;
1226			{
1227				vec4 splane = (spot_lights.data[idx].shadow_matrix * vec4(vertex - normalize(normal_interp) * spot_lights.data[idx].transmittance_bias, 1.0));
1228				splane /= splane.w;
1229				splane.xy = splane.xy * spot_lights.data[idx].atlas_rect.zw + spot_lights.data[idx].atlas_rect.xy;
1230		
1231				float shadow_z = textureLod(sampler2D(shadow_atlas, SAMPLER_LINEAR_CLAMP), splane.xy, 0.0).r;
1232		
1233				shadow_z = shadow_z * 2.0 - 1.0;
1234				float z_far = 1.0 / spot_lights.data[idx].inv_radius;
1235				float z_near = 0.01;
1236				shadow_z = 2.0 * z_near * z_far / (z_far + z_near - shadow_z * (z_far - z_near));
1237		
1238				//distance to light plane
1239				float z = dot(spot_dir, -light_rel_vec);
1240				transmittance_z = z - shadow_z;
1241			}
1242		#endif //LIGHT_TRANSMITTANCE_USED
1243		
1244			if (sc_use_light_projector && spot_lights.data[idx].projector_rect != vec4(0.0)) {
1245				vec4 splane = (spot_lights.data[idx].shadow_matrix * vec4(vertex, 1.0));
1246				splane /= splane.w;
1247		
1248				vec2 proj_uv = splane.xy * spot_lights.data[idx].projector_rect.zw;
1249		
1250				if (sc_projector_use_mipmaps) {
1251					//ensure we have proper mipmaps
1252					vec4 splane_ddx = (spot_lights.data[idx].shadow_matrix * vec4(vertex + vertex_ddx, 1.0));
1253					splane_ddx /= splane_ddx.w;
1254					vec2 proj_uv_ddx = splane_ddx.xy * spot_lights.data[idx].projector_rect.zw - proj_uv;
1255		
1256					vec4 splane_ddy = (spot_lights.data[idx].shadow_matrix * vec4(vertex + vertex_ddy, 1.0));
1257					splane_ddy /= splane_ddy.w;
1258					vec2 proj_uv_ddy = splane_ddy.xy * spot_lights.data[idx].projector_rect.zw - proj_uv;
1259		
1260					vec4 proj = textureGrad(sampler2D(decal_atlas_srgb, light_projector_sampler), proj_uv + spot_lights.data[idx].projector_rect.xy, proj_uv_ddx, proj_uv_ddy);
1261					color *= proj.rgb * proj.a;
1262				} else {
1263					vec4 proj = textureLod(sampler2D(decal_atlas_srgb, light_projector_sampler), proj_uv + spot_lights.data[idx].projector_rect.xy, 0.0);
1264					color *= proj.rgb * proj.a;
1265				}
1266			}
1267			light_attenuation *= shadow;
1268		
1269			light_compute(normal, normalize(light_rel_vec), eye_vec, size_A, color, false, light_attenuation, f0, orms, spot_lights.data[idx].specular_amount, albedo, alpha,
1270		#ifdef LIGHT_BACKLIGHT_USED
1271					backlight,
1272		#endif
1273		#ifdef LIGHT_TRANSMITTANCE_USED
1274					transmittance_color,
1275					transmittance_depth,
1276					transmittance_boost,
1277					transmittance_z,
1278		#endif
1279		#ifdef LIGHT_RIM_USED
1280					rim * spot_attenuation, rim_tint,
1281		#endif
1282		#ifdef LIGHT_CLEARCOAT_USED
1283					clearcoat, clearcoat_roughness, vertex_normal,
1284		#endif
1285		#ifdef LIGHT_ANISOTROPY_USED
1286					binormal, tangent, anisotropy,
1287		#endif
1288					diffuse_light, specular_light);
1289		}
1290		
1291		void reflection_process(uint ref_index, vec3 vertex, vec3 ref_vec, vec3 normal, float roughness, vec3 ambient_light, vec3 specular_light, inout vec4 ambient_accum, inout vec4 reflection_accum) {
1292			vec3 box_extents = reflections.data[ref_index].box_extents;
1293			vec3 local_pos = (reflections.data[ref_index].local_matrix * vec4(vertex, 1.0)).xyz;
1294		
1295			if (any(greaterThan(abs(local_pos), box_extents))) { //out of the reflection box
1296				return;
1297			}
1298		
1299			vec3 inner_pos = abs(local_pos / box_extents);
1300			float blend = max(inner_pos.x, max(inner_pos.y, inner_pos.z));
1301			//make blend more rounded
1302			blend = mix(length(inner_pos), blend, blend);
1303			blend *= blend;
1304			blend = max(0.0, 1.0 - blend);
1305		
1306			if (reflections.data[ref_index].intensity > 0.0) { // compute reflection
1307		
1308				vec3 local_ref_vec = (reflections.data[ref_index].local_matrix * vec4(ref_vec, 0.0)).xyz;
1309		
1310				if (reflections.data[ref_index].box_project) { //box project
1311		
1312					vec3 nrdir = normalize(local_ref_vec);
1313					vec3 rbmax = (box_extents - local_pos) / nrdir;
1314					vec3 rbmin = (-box_extents - local_pos) / nrdir;
1315		
1316					vec3 rbminmax = mix(rbmin, rbmax, greaterThan(nrdir, vec3(0.0, 0.0, 0.0)));
1317		
1318					float fa = min(min(rbminmax.x, rbminmax.y), rbminmax.z);
1319					vec3 posonbox = local_pos + nrdir * fa;
1320					local_ref_vec = posonbox - reflections.data[ref_index].box_offset;
1321				}
1322		
1323				vec4 reflection;
1324		
1325				reflection.rgb = textureLod(samplerCubeArray(reflection_atlas, SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP), vec4(local_ref_vec, reflections.data[ref_index].index), roughness * MAX_ROUGHNESS_LOD).rgb * sc_luminance_multiplier;
1326				reflection.rgb *= reflections.data[ref_index].exposure_normalization;
1327				if (reflections.data[ref_index].exterior) {
1328					reflection.rgb = mix(specular_light, reflection.rgb, blend);
1329				}
1330		
1331				reflection.rgb *= reflections.data[ref_index].intensity; //intensity
1332				reflection.a = blend;
1333				reflection.rgb *= reflection.a;
1334		
1335				reflection_accum += reflection;
1336			}
1337		
1338			switch (reflections.data[ref_index].ambient_mode) {
1339				case REFLECTION_AMBIENT_DISABLED: {
1340					//do nothing
1341				} break;
1342				case REFLECTION_AMBIENT_ENVIRONMENT: {
1343					//do nothing
1344					vec3 local_amb_vec = (reflections.data[ref_index].local_matrix * vec4(normal, 0.0)).xyz;
1345		
1346					vec4 ambient_out;
1347		
1348					ambient_out.rgb = textureLod(samplerCubeArray(reflection_atlas, SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP), vec4(local_amb_vec, reflections.data[ref_index].index), MAX_ROUGHNESS_LOD).rgb;
1349					ambient_out.rgb *= reflections.data[ref_index].exposure_normalization;
1350					ambient_out.a = blend;
1351					if (reflections.data[ref_index].exterior) {
1352						ambient_out.rgb = mix(ambient_light, ambient_out.rgb, blend);
1353					}
1354		
1355					ambient_out.rgb *= ambient_out.a;
1356					ambient_accum += ambient_out;
1357				} break;
1358				case REFLECTION_AMBIENT_COLOR: {
1359					vec4 ambient_out;
1360					ambient_out.a = blend;
1361					ambient_out.rgb = reflections.data[ref_index].ambient;
1362					if (reflections.data[ref_index].exterior) {
1363						ambient_out.rgb = mix(ambient_light, ambient_out.rgb, blend);
1364					}
1365					ambient_out.rgb *= ambient_out.a;
1366					ambient_accum += ambient_out;
1367				} break;
1368			}
1369		}
1370		
1371		float blur_shadow(float shadow) {
1372			return shadow;
1373		#if 0
1374			//disabling for now, will investigate later
1375			float interp_shadow = shadow;
1376			if (gl_HelperInvocation) {
1377				interp_shadow = -4.0; // technically anything below -4 will do but just to make sure
1378			}
1379		
1380			uvec2 fc2 = uvec2(gl_FragCoord.xy);
1381			interp_shadow -= dFdx(interp_shadow) * (float(fc2.x & 1) - 0.5);
1382			interp_shadow -= dFdy(interp_shadow) * (float(fc2.y & 1) - 0.5);
1383		
1384			if (interp_shadow >= 0.0) {
1385				shadow = interp_shadow;
1386			}
1387			return shadow;
1388		#endif
1389		}
1390		
1391		
1392		#endif //!defined(MODE_RENDER_DEPTH) && !defined(MODE_UNSHADED)
1393		
1394		#ifndef MODE_RENDER_DEPTH
1395		
1396		/*
1397			Only supporting normal fog here.
1398		*/
1399		
1400		vec4 fog_process(vec3 vertex) {
1401			vec3 fog_color = scene_data_block.data.fog_light_color;
1402		
1403			if (scene_data_block.data.fog_aerial_perspective > 0.0) {
1404				vec3 sky_fog_color = vec3(0.0);
1405				vec3 cube_view = scene_data_block.data.radiance_inverse_xform * vertex;
1406				// mip_level always reads from the second mipmap and higher so the fog is always slightly blurred
1407				float mip_level = mix(1.0 / MAX_ROUGHNESS_LOD, 1.0, 1.0 - (abs(vertex.z) - scene_data_block.data.z_near) / (scene_data_block.data.z_far - scene_data_block.data.z_near));
1408		#ifdef USE_RADIANCE_CUBEMAP_ARRAY
1409				float lod, blend;
1410				blend = modf(mip_level * MAX_ROUGHNESS_LOD, lod);
1411				sky_fog_color = texture(samplerCubeArray(radiance_cubemap, SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP), vec4(cube_view, lod)).rgb;
1412				sky_fog_color = mix(sky_fog_color, texture(samplerCubeArray(radiance_cubemap, SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP), vec4(cube_view, lod + 1)).rgb, blend);
1413		#else
1414				sky_fog_color = textureLod(samplerCube(radiance_cubemap, SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP), cube_view, mip_level * MAX_ROUGHNESS_LOD).rgb;
1415		#endif //USE_RADIANCE_CUBEMAP_ARRAY
1416				fog_color = mix(fog_color, sky_fog_color, scene_data_block.data.fog_aerial_perspective);
1417			}
1418		
1419			if (scene_data_block.data.fog_sun_scatter > 0.001) {
1420				vec4 sun_scatter = vec4(0.0);
1421				float sun_total = 0.0;
1422				vec3 view = normalize(vertex);
1423		
1424				for (uint i = 0; i < scene_data_block.data.directional_light_count; i++) {
1425					vec3 light_color = directional_lights.data[i].color * directional_lights.data[i].energy;
1426					float light_amount = pow(max(dot(view, directional_lights.data[i].direction), 0.0), 8.0);
1427					fog_color += light_color * light_amount * scene_data_block.data.fog_sun_scatter;
1428				}
1429			}
1430		
1431			float fog_amount = 1.0 - exp(min(0.0, -length(vertex) * scene_data_block.data.fog_density));
1432		
1433			if (abs(scene_data_block.data.fog_height_density) >= 0.0001) {
1434				float y = (scene_data_block.data.inv_view_matrix * vec4(vertex, 1.0)).y;
1435		
1436				float y_dist = y - scene_data_block.data.fog_height;
1437		
1438				float vfog_amount = 1.0 - exp(min(0.0, y_dist * scene_data_block.data.fog_height_density));
1439		
1440				fog_amount = max(vfog_amount, fog_amount);
1441			}
1442		
1443			return vec4(fog_color, fog_amount);
1444		}
1445		
1446		#endif //!MODE_RENDER DEPTH
1447		
1448		#define scene_data scene_data_block.data
1449		
1450		void main() {
1451		#ifdef MODE_DUAL_PARABOLOID
1452		
1453			if (dp_clip > 0.0)
1454				discard;
1455		#endif
1456		
1457			//lay out everything, whatever is unused is optimized away anyway
1458			vec3 vertex = vertex_interp;
1459		#ifdef USE_MULTIVIEW
1460			vec3 eye_offset = scene_data.eye_offset[ViewIndex].xyz;
1461			vec3 view = -normalize(vertex_interp - eye_offset);
1462		#else
1463			vec3 eye_offset = vec3(0.0, 0.0, 0.0);
1464			vec3 view = -normalize(vertex_interp);
1465		#endif
1466			vec3 albedo = vec3(1.0);
1467			vec3 backlight = vec3(0.0);
1468			vec4 transmittance_color = vec4(0.0);
1469			float transmittance_depth = 0.0;
1470			float transmittance_boost = 0.0;
1471			float metallic = 0.0;
1472			float specular = 0.5;
1473			vec3 emission = vec3(0.0);
1474			float roughness = 1.0;
1475			float rim = 0.0;
1476			float rim_tint = 0.0;
1477			float clearcoat = 0.0;
1478			float clearcoat_roughness = 0.0;
1479			float anisotropy = 0.0;
1480			vec2 anisotropy_flow = vec2(1.0, 0.0);
1481		#ifndef FOG_DISABLED
1482			vec4 fog = vec4(0.0);
1483		#endif // !FOG_DISABLED
1484		#if defined(CUSTOM_RADIANCE_USED)
1485			vec4 custom_radiance = vec4(0.0);
1486		#endif
1487		#if defined(CUSTOM_IRRADIANCE_USED)
1488			vec4 custom_irradiance = vec4(0.0);
1489		#endif
1490		
1491			float ao = 1.0;
1492			float ao_light_affect = 0.0;
1493		
1494			float alpha = 1.0;
1495		
1496		#if defined(TANGENT_USED) || defined(NORMAL_MAP_USED) || defined(LIGHT_ANISOTROPY_USED)
1497			vec3 binormal = normalize(binormal_interp);
1498			vec3 tangent = normalize(tangent_interp);
1499		#else
1500			vec3 binormal = vec3(0.0);
1501			vec3 tangent = vec3(0.0);
1502		#endif
1503		
1504		#ifdef NORMAL_USED
1505			vec3 normal = normalize(normal_interp);
1506		
1507		#if defined(DO_SIDE_CHECK)
1508			if (!gl_FrontFacing) {
1509				normal = -normal;
1510			}
1511		#endif
1512		
1513		#endif //NORMAL_USED
1514		
1515		#ifdef UV_USED
1516			vec2 uv = uv_interp;
1517		#endif
1518		
1519		#if defined(UV2_USED) || defined(USE_LIGHTMAP)
1520			vec2 uv2 = uv2_interp;
1521		#endif
1522		
1523		#if defined(COLOR_USED)
1524			vec4 color = color_interp;
1525		#endif
1526		
1527		#if defined(NORMAL_MAP_USED)
1528		
1529			vec3 normal_map = vec3(0.5);
1530		#endif
1531		
1532			float normal_map_depth = 1.0;
1533		
1534			vec2 screen_uv = gl_FragCoord.xy * scene_data.screen_pixel_size;
1535		
1536			float sss_strength = 0.0;
1537		
1538		#ifdef ALPHA_SCISSOR_USED
1539			float alpha_scissor_threshold = 1.0;
1540		#endif // ALPHA_SCISSOR_USED
1541		
1542		#ifdef ALPHA_HASH_USED
1543			float alpha_hash_scale = 1.0;
1544		#endif // ALPHA_HASH_USED
1545		
1546		#ifdef ALPHA_ANTIALIASING_EDGE_USED
1547			float alpha_antialiasing_edge = 0.0;
1548			vec2 alpha_texture_coordinate = vec2(0.0, 0.0);
1549		#endif // ALPHA_ANTIALIASING_EDGE_USED
1550		
1551			mat4 inv_view_matrix = scene_data.inv_view_matrix;
1552			mat4 read_model_matrix = instances.data[draw_call.instance_index].transform;
1553		#ifdef USE_DOUBLE_PRECISION
1554			read_model_matrix[0][3] = 0.0;
1555			read_model_matrix[1][3] = 0.0;
1556			read_model_matrix[2][3] = 0.0;
1557			inv_view_matrix[0][3] = 0.0;
1558			inv_view_matrix[1][3] = 0.0;
1559			inv_view_matrix[2][3] = 0.0;
1560		#endif
1561		
1562			mat4 read_view_matrix = scene_data.view_matrix;
1563			vec2 read_viewport_size = scene_data.viewport_size;
1564		
1565			{
1566		#CODE : FRAGMENT
1567			}
1568		
1569		#ifdef LIGHT_TRANSMITTANCE_USED
1570		#ifdef SSS_MODE_SKIN
1571			transmittance_color.a = sss_strength;
1572		#else
1573			transmittance_color.a *= sss_strength;
1574		#endif
1575		#endif
1576		
1577		#ifndef USE_SHADOW_TO_OPACITY
1578		
1579		#ifdef ALPHA_SCISSOR_USED
1580			if (alpha < alpha_scissor_threshold) {
1581				discard;
1582			}
1583		#endif // ALPHA_SCISSOR_USED
1584		
1585		// alpha hash can be used in unison with alpha antialiasing
1586		#ifdef ALPHA_HASH_USED
1587			vec3 object_pos = (inverse(read_model_matrix) * inv_view_matrix * vec4(vertex, 1.0)).xyz;
1588			if (alpha < compute_alpha_hash_threshold(object_pos, alpha_hash_scale)) {
1589				discard;
1590			}
1591		#endif // ALPHA_HASH_USED
1592		
1593		// If we are not edge antialiasing, we need to remove the output alpha channel from scissor and hash
1594		#if (defined(ALPHA_SCISSOR_USED) || defined(ALPHA_HASH_USED)) && !defined(ALPHA_ANTIALIASING_EDGE_USED)
1595			alpha = 1.0;
1596		#endif
1597		
1598		#ifdef ALPHA_ANTIALIASING_EDGE_USED
1599		// If alpha scissor is used, we must further the edge threshold, otherwise we won't get any edge feather
1600		#ifdef ALPHA_SCISSOR_USED
1601			alpha_antialiasing_edge = clamp(alpha_scissor_threshold + alpha_antialiasing_edge, 0.0, 1.0);
1602		#endif
1603			alpha = compute_alpha_antialiasing_edge(alpha, alpha_texture_coordinate, alpha_antialiasing_edge);
1604		#endif // ALPHA_ANTIALIASING_EDGE_USED
1605		
1606		#ifdef MODE_RENDER_DEPTH
1607		#if defined(USE_OPAQUE_PREPASS) || defined(ALPHA_ANTIALIASING_EDGE_USED)
1608			if (alpha < scene_data.opaque_prepass_threshold) {
1609				discard;
1610			}
1611		#endif // USE_OPAQUE_PREPASS || ALPHA_ANTIALIASING_EDGE_USED
1612		#endif // MODE_RENDER_DEPTH
1613		
1614		#endif // !USE_SHADOW_TO_OPACITY
1615		
1616		#ifdef NORMAL_MAP_USED
1617		
1618			normal_map.xy = normal_map.xy * 2.0 - 1.0;
1619			normal_map.z = sqrt(max(0.0, 1.0 - dot(normal_map.xy, normal_map.xy))); //always ignore Z, as it can be RG packed, Z may be pos/neg, etc.
1620		
1621			normal = normalize(mix(normal, tangent * normal_map.x + binormal * normal_map.y + normal * normal_map.z, normal_map_depth));
1622		
1623		#endif
1624		
1625		#ifdef LIGHT_ANISOTROPY_USED
1626		
1627			if (anisotropy > 0.01) {
1628				//rotation matrix
1629				mat3 rot = mat3(tangent, binormal, normal);
1630				//make local to space
1631				tangent = normalize(rot * vec3(anisotropy_flow.x, anisotropy_flow.y, 0.0));
1632				binormal = normalize(rot * vec3(-anisotropy_flow.y, anisotropy_flow.x, 0.0));
1633			}
1634		
1635		#endif
1636		
1637		#ifdef ENABLE_CLIP_ALPHA
1638			if (albedo.a < 0.99) {
1639				//used for doublepass and shadowmapping
1640				discard;
1641			}
1642		#endif
1643		
1644			/////////////////////// FOG //////////////////////
1645		#ifndef MODE_RENDER_DEPTH
1646		
1647		#ifndef FOG_DISABLED
1648		#ifndef CUSTOM_FOG_USED
1649			// fog must be processed as early as possible and then packed.
1650			// to maximize VGPR usage
1651			// Draw "fixed" fog before volumetric fog to ensure volumetric fog can appear in front of the sky.
1652		
1653			if (!sc_disable_fog && scene_data.fog_enabled) {
1654				fog = fog_process(vertex);
1655			}
1656		
1657		#endif //!CUSTOM_FOG_USED
1658		
1659			uint fog_rg = packHalf2x16(fog.rg);
1660			uint fog_ba = packHalf2x16(fog.ba);
1661		
1662		#endif //!FOG_DISABLED
1663		#endif //!MODE_RENDER_DEPTH
1664		
1665			/////////////////////// DECALS ////////////////////////////////
1666		
1667		#ifndef MODE_RENDER_DEPTH
1668		
1669			vec3 vertex_ddx = dFdx(vertex);
1670			vec3 vertex_ddy = dFdy(vertex);
1671		
1672			if (!sc_disable_decals) { //Decals
1673				// must implement
1674		
1675				uint decal_indices = instances.data[draw_call.instance_index].decals.x;
1676				for (uint i = 0; i < 8; i++) {
1677					uint decal_index = decal_indices & 0xFF;
1678					if (i == 3) {
1679						decal_indices = instances.data[draw_call.instance_index].decals.y;
1680					} else {
1681						decal_indices = decal_indices >> 8;
1682					}
1683		
1684					if (decal_index == 0xFF) {
1685						break;
1686					}
1687		
1688					if (!bool(decals.data[decal_index].mask & instances.data[draw_call.instance_index].layer_mask)) {
1689						continue; //not masked
1690					}
1691		
1692					vec3 uv_local = (decals.data[decal_index].xform * vec4(vertex, 1.0)).xyz;
1693					if (any(lessThan(uv_local, vec3(0.0, -1.0, 0.0))) || any(greaterThan(uv_local, vec3(1.0)))) {
1694						continue; //out of decal
1695					}
1696		
1697					float fade = pow(1.0 - (uv_local.y > 0.0 ? uv_local.y : -uv_local.y), uv_local.y > 0.0 ? decals.data[decal_index].upper_fade : decals.data[decal_index].lower_fade);
1698		
1699					if (decals.data[decal_index].normal_fade > 0.0) {
1700						fade *= smoothstep(decals.data[decal_index].normal_fade, 1.0, dot(normal_interp, decals.data[decal_index].normal) * 0.5 + 0.5);
1701					}
1702		
1703					//we need ddx/ddy for mipmaps, so simulate them
1704					vec2 ddx = (decals.data[decal_index].xform * vec4(vertex_ddx, 0.0)).xz;
1705					vec2 ddy = (decals.data[decal_index].xform * vec4(vertex_ddy, 0.0)).xz;
1706		
1707					if (decals.data[decal_index].albedo_rect != vec4(0.0)) {
1708						//has albedo
1709						vec4 decal_albedo;
1710						if (sc_decal_use_mipmaps) {
1711							decal_albedo = textureGrad(sampler2D(decal_atlas_srgb, decal_sampler), uv_local.xz * decals.data[decal_index].albedo_rect.zw + decals.data[decal_index].albedo_rect.xy, ddx * decals.data[decal_index].albedo_rect.zw, ddy * decals.data[decal_index].albedo_rect.zw);
1712						} else {
1713							decal_albedo = textureLod(sampler2D(decal_atlas_srgb, decal_sampler), uv_local.xz * decals.data[decal_index].albedo_rect.zw + decals.data[decal_index].albedo_rect.xy, 0.0);
1714						}
1715						decal_albedo *= decals.data[decal_index].modulate;
1716						decal_albedo.a *= fade;
1717						albedo = mix(albedo, decal_albedo.rgb, decal_albedo.a * decals.data[decal_index].albedo_mix);
1718		
1719						if (decals.data[decal_index].normal_rect != vec4(0.0)) {
1720							vec3 decal_normal;
1721							if (sc_decal_use_mipmaps) {
1722								decal_normal = textureGrad(sampler2D(decal_atlas, decal_sampler), uv_local.xz * decals.data[decal_index].normal_rect.zw + decals.data[decal_index].normal_rect.xy, ddx * decals.data[decal_index].normal_rect.zw, ddy * decals.data[decal_index].normal_rect.zw).xyz;
1723							} else {
1724								decal_normal = textureLod(sampler2D(decal_atlas, decal_sampler), uv_local.xz * decals.data[decal_index].normal_rect.zw + decals.data[decal_index].normal_rect.xy, 0.0).xyz;
1725							}
1726							decal_normal.xy = decal_normal.xy * vec2(2.0, -2.0) - vec2(1.0, -1.0); //users prefer flipped y normal maps in most authoring software
1727							decal_normal.z = sqrt(max(0.0, 1.0 - dot(decal_normal.xy, decal_normal.xy)));
1728							//convert to view space, use xzy because y is up
1729							decal_normal = (decals.data[decal_index].normal_xform * decal_normal.xzy).xyz;
1730		
1731							normal = normalize(mix(normal, decal_normal, decal_albedo.a));
1732						}
1733		
1734						if (decals.data[decal_index].orm_rect != vec4(0.0)) {
1735							vec3 decal_orm;
1736							if (sc_decal_use_mipmaps) {
1737								decal_orm = textureGrad(sampler2D(decal_atlas, decal_sampler), uv_local.xz * decals.data[decal_index].orm_rect.zw + decals.data[decal_index].orm_rect.xy, ddx * decals.data[decal_index].orm_rect.zw, ddy * decals.data[decal_index].orm_rect.zw).xyz;
1738							} else {
1739								decal_orm = textureLod(sampler2D(decal_atlas, decal_sampler), uv_local.xz * decals.data[decal_index].orm_rect.zw + decals.data[decal_index].orm_rect.xy, 0.0).xyz;
1740							}
1741							ao = mix(ao, decal_orm.r, decal_albedo.a);
1742							roughness = mix(roughness, decal_orm.g, decal_albedo.a);
1743							metallic = mix(metallic, decal_orm.b, decal_albedo.a);
1744						}
1745					}
1746		
1747					if (decals.data[decal_index].emission_rect != vec4(0.0)) {
1748						//emission is additive, so its independent from albedo
1749						if (sc_decal_use_mipmaps) {
1750							emission += textureGrad(sampler2D(decal_atlas_srgb, decal_sampler), uv_local.xz * decals.data[decal_index].emission_rect.zw + decals.data[decal_index].emission_rect.xy, ddx * decals.data[decal_index].emission_rect.zw, ddy * decals.data[decal_index].emission_rect.zw).xyz * decals.data[decal_index].emission_energy * fade;
1751						} else {
1752							emission += textureLod(sampler2D(decal_atlas_srgb, decal_sampler), uv_local.xz * decals.data[decal_index].emission_rect.zw + decals.data[decal_index].emission_rect.xy, 0.0).xyz * decals.data[decal_index].emission_energy * fade;
1753						}
1754					}
1755				}
1756			} //Decals
1757		#endif //!MODE_RENDER_DEPTH
1758		
1759			/////////////////////// LIGHTING //////////////////////////////
1760		
1761		#ifdef NORMAL_USED
1762			if (scene_data.roughness_limiter_enabled) {
1763				//https://www.jp.square-enix.com/tech/library/pdf/ImprovedGeometricSpecularAA.pdf
1764				float roughness2 = roughness * roughness;
1765				vec3 dndu = dFdx(normal), dndv = dFdy(normal);
1766				float variance = scene_data.roughness_limiter_amount * (dot(dndu, dndu) + dot(dndv, dndv));
1767				float kernelRoughness2 = min(2.0 * variance, scene_data.roughness_limiter_limit); //limit effect
1768				float filteredRoughness2 = min(1.0, roughness2 + kernelRoughness2);
1769				roughness = sqrt(filteredRoughness2);
1770			}
1771		#endif // NORMAL_USED
1772			//apply energy conservation
1773		
1774			vec3 specular_light = vec3(0.0, 0.0, 0.0);
1775			vec3 diffuse_light = vec3(0.0, 0.0, 0.0);
1776			vec3 ambient_light = vec3(0.0, 0.0, 0.0);
1777		
1778		#ifndef MODE_UNSHADED
1779			// Used in regular draw pass and when drawing SDFs for SDFGI and materials for VoxelGI.
1780			emission *= scene_data.emissive_exposure_normalization;
1781		#endif
1782		
1783		#if !defined(MODE_RENDER_DEPTH) && !defined(MODE_UNSHADED)
1784		
1785			if (scene_data.use_reflection_cubemap) {
1786		#ifdef LIGHT_ANISOTROPY_USED
1787				// https://google.github.io/filament/Filament.html#lighting/imagebasedlights/anisotropy
1788				vec3 anisotropic_direction = anisotropy >= 0.0 ? binormal : tangent;
1789				vec3 anisotropic_tangent = cross(anisotropic_direction, view);
1790				vec3 anisotropic_normal = cross(anisotropic_tangent, anisotropic_direction);
1791				vec3 bent_normal = normalize(mix(normal, anisotropic_normal, abs(anisotropy) * clamp(5.0 * roughness, 0.0, 1.0)));
1792				vec3 ref_vec = reflect(-view, bent_normal);
1793				ref_vec = mix(ref_vec, bent_normal, roughness * roughness);
1794		#else
1795				vec3 ref_vec = reflect(-view, normal);
1796				ref_vec = mix(ref_vec, normal, roughness * roughness);
1797		#endif
1798				float horizon = min(1.0 + dot(ref_vec, normal), 1.0);
1799				ref_vec = scene_data.radiance_inverse_xform * ref_vec;
1800		#ifdef USE_RADIANCE_CUBEMAP_ARRAY
1801		
1802				float lod, blend;
1803				blend = modf(sqrt(roughness) * MAX_ROUGHNESS_LOD, lod);
1804				specular_light = texture(samplerCubeArray(radiance_cubemap, SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP), vec4(ref_vec, lod)).rgb;
1805				specular_light = mix(specular_light, texture(samplerCubeArray(radiance_cubemap, SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP), vec4(ref_vec, lod + 1)).rgb, blend);
1806		
1807		#else // USE_RADIANCE_CUBEMAP_ARRAY
1808				specular_light = textureLod(samplerCube(radiance_cubemap, SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP), ref_vec, sqrt(roughness) * MAX_ROUGHNESS_LOD).rgb;
1809		
1810		#endif //USE_RADIANCE_CUBEMAP_ARRAY
1811				specular_light *= sc_luminance_multiplier;
1812				specular_light *= scene_data.IBL_exposure_normalization;
1813				specular_light *= horizon * horizon;
1814				specular_light *= scene_data.ambient_light_color_energy.a;
1815			}
1816		
1817		#if defined(CUSTOM_RADIANCE_USED)
1818			specular_light = mix(specular_light, custom_radiance.rgb, custom_radiance.a);
1819		#endif // CUSTOM_RADIANCE_USED
1820		
1821		#ifndef USE_LIGHTMAP
1822			//lightmap overrides everything
1823			if (scene_data.use_ambient_light) {
1824				ambient_light = scene_data.ambient_light_color_energy.rgb;
1825		
1826				if (scene_data.use_ambient_cubemap) {
1827					vec3 ambient_dir = scene_data.radiance_inverse_xform * normal;
1828		#ifdef USE_RADIANCE_CUBEMAP_ARRAY
1829					vec3 cubemap_ambient = texture(samplerCubeArray(radiance_cubemap, SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP), vec4(ambient_dir, MAX_ROUGHNESS_LOD)).rgb;
1830		#else
1831					vec3 cubemap_ambient = textureLod(samplerCube(radiance_cubemap, SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP), ambient_dir, MAX_ROUGHNESS_LOD).rgb;
1832		#endif //USE_RADIANCE_CUBEMAP_ARRAY
1833					cubemap_ambient *= sc_luminance_multiplier;
1834					cubemap_ambient *= scene_data.IBL_exposure_normalization;
1835					ambient_light = mix(ambient_light, cubemap_ambient * scene_data.ambient_light_color_energy.a, scene_data.ambient_color_sky_mix);
1836				}
1837			}
1838		#endif // !USE_LIGHTMAP
1839		
1840		#if defined(CUSTOM_IRRADIANCE_USED)
1841			ambient_light = mix(ambient_light, custom_irradiance.rgb, custom_irradiance.a);
1842		#endif // CUSTOM_IRRADIANCE_USED
1843		#ifdef LIGHT_CLEARCOAT_USED
1844		
1845			if (scene_data.use_reflection_cubemap) {
1846				vec3 n = normalize(normal_interp); // We want to use geometric normal, not normal_map
1847				float NoV = max(dot(n, view), 0.0001);
1848				vec3 ref_vec = reflect(-view, n);
1849				ref_vec = mix(ref_vec, n, clearcoat_roughness * clearcoat_roughness);
1850				// The clear coat layer assumes an IOR of 1.5 (4% reflectance)
1851				float Fc = clearcoat * (0.04 + 0.96 * SchlickFresnel(NoV));
1852				float attenuation = 1.0 - Fc;
1853				ambient_light *= attenuation;
1854				specular_light *= attenuation;
1855		
1856				float horizon = min(1.0 + dot(ref_vec, normal), 1.0);
1857				ref_vec = scene_data.radiance_inverse_xform * ref_vec;
1858				float roughness_lod = mix(0.001, 0.1, sqrt(clearcoat_roughness)) * MAX_ROUGHNESS_LOD;
1859		#ifdef USE_RADIANCE_CUBEMAP_ARRAY
1860		
1861				float lod, blend;
1862				blend = modf(roughness_lod, lod);
1863				vec3 clearcoat_light = texture(samplerCubeArray(radiance_cubemap, SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP), vec4(ref_vec, lod)).rgb;
1864				clearcoat_light = mix(clearcoat_light, texture(samplerCubeArray(radiance_cubemap, SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP), vec4(ref_vec, lod + 1)).rgb, blend);
1865		
1866		#else
1867				vec3 clearcoat_light = textureLod(samplerCube(radiance_cubemap, SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP), ref_vec, roughness_lod).rgb;
1868		
1869		#endif //USE_RADIANCE_CUBEMAP_ARRAY
1870				specular_light += clearcoat_light * horizon * horizon * Fc * scene_data.ambient_light_color_energy.a;
1871			}
1872		#endif
1873		#endif //!defined(MODE_RENDER_DEPTH) && !defined(MODE_UNSHADED)
1874		
1875			//radiance
1876		
1877		#if !defined(MODE_RENDER_DEPTH) && !defined(MODE_UNSHADED)
1878		
1879		#ifdef USE_LIGHTMAP
1880		
1881			//lightmap
1882			if (bool(instances.data[draw_call.instance_index].flags & INSTANCE_FLAGS_USE_LIGHTMAP_CAPTURE)) { //has lightmap capture
1883				uint index = instances.data[draw_call.instance_index].gi_offset;
1884		
1885				vec3 wnormal = mat3(scene_data.inv_view_matrix) * normal;
1886				const float c1 = 0.429043;
1887				const float c2 = 0.511664;
1888				const float c3 = 0.743125;
1889				const float c4 = 0.886227;
1890				const float c5 = 0.247708;
1891				ambient_light += (c1 * lightmap_captures.data[index].sh[8].rgb * (wnormal.x * wnormal.x - wnormal.y * wnormal.y) +
1892										 c3 * lightmap_captures.data[index].sh[6].rgb * wnormal.z * wnormal.z +
1893										 c4 * lightmap_captures.data[index].sh[0].rgb -
1894										 c5 * lightmap_captures.data[index].sh[6].rgb +
1895										 2.0 * c1 * lightmap_captures.data[index].sh[4].rgb * wnormal.x * wnormal.y +
1896										 2.0 * c1 * lightmap_captures.data[index].sh[7].rgb * wnormal.x * wnormal.z +
1897										 2.0 * c1 * lightmap_captures.data[index].sh[5].rgb * wnormal.y * wnormal.z +
1898										 2.0 * c2 * lightmap_captures.data[index].sh[3].rgb * wnormal.x +
1899										 2.0 * c2 * lightmap_captures.data[index].sh[1].rgb * wnormal.y +
1900										 2.0 * c2 * lightmap_captures.data[index].sh[2].rgb * wnormal.z) *
1901						scene_data.emissive_exposure_normalization;
1902		
1903			} else if (bool(instances.data[draw_call.instance_index].flags & INSTANCE_FLAGS_USE_LIGHTMAP)) { // has actual lightmap
1904				bool uses_sh = bool(instances.data[draw_call.instance_index].flags & INSTANCE_FLAGS_USE_SH_LIGHTMAP);
1905				uint ofs = instances.data[draw_call.instance_index].gi_offset & 0xFFFF;
1906				uint slice = instances.data[draw_call.instance_index].gi_offset >> 16;
1907				vec3 uvw;
1908				uvw.xy = uv2 * instances.data[draw_call.instance_index].lightmap_uv_scale.zw + instances.data[draw_call.instance_index].lightmap_uv_scale.xy;
1909				uvw.z = float(slice);
1910		
1911				if (uses_sh) {
1912					uvw.z *= 4.0; //SH textures use 4 times more data
1913					vec3 lm_light_l0 = textureLod(sampler2DArray(lightmap_textures[ofs], SAMPLER_LINEAR_CLAMP), uvw + vec3(0.0, 0.0, 0.0), 0.0).rgb;
1914					vec3 lm_light_l1n1 = textureLod(sampler2DArray(lightmap_textures[ofs], SAMPLER_LINEAR_CLAMP), uvw + vec3(0.0, 0.0, 1.0), 0.0).rgb;
1915					vec3 lm_light_l1_0 = textureLod(sampler2DArray(lightmap_textures[ofs], SAMPLER_LINEAR_CLAMP), uvw + vec3(0.0, 0.0, 2.0), 0.0).rgb;
1916					vec3 lm_light_l1p1 = textureLod(sampler2DArray(lightmap_textures[ofs], SAMPLER_LINEAR_CLAMP), uvw + vec3(0.0, 0.0, 3.0), 0.0).rgb;
1917		
1918					vec3 n = normalize(lightmaps.data[ofs].normal_xform * normal);
1919					float exposure_normalization = lightmaps.data[ofs].exposure_normalization;
1920		
1921					ambient_light += lm_light_l0 * 0.282095f;
1922					ambient_light += lm_light_l1n1 * 0.32573 * n.y * exposure_normalization;
1923					ambient_light += lm_light_l1_0 * 0.32573 * n.z * exposure_normalization;
1924					ambient_light += lm_light_l1p1 * 0.32573 * n.x * exposure_normalization;
1925					if (metallic > 0.01) { // since the more direct bounced light is lost, we can kind of fake it with this trick
1926						vec3 r = reflect(normalize(-vertex), normal);
1927						specular_light += lm_light_l1n1 * 0.32573 * r.y * exposure_normalization;
1928						specular_light += lm_light_l1_0 * 0.32573 * r.z * exposure_normalization;
1929						specular_light += lm_light_l1p1 * 0.32573 * r.x * exposure_normalization;
1930					}
1931		
1932				} else {
1933					ambient_light += textureLod(sampler2DArray(lightmap_textures[ofs], SAMPLER_LINEAR_CLAMP), uvw, 0.0).rgb * lightmaps.data[ofs].exposure_normalization;
1934				}
1935			}
1936		
1937			// No GI nor non low end mode...
1938		
1939		#endif // USE_LIGHTMAP
1940		
1941			// skipping ssao, do we remove ssao totally?
1942		
1943			if (!sc_disable_reflection_probes) { //Reflection probes
1944				vec4 reflection_accum = vec4(0.0, 0.0, 0.0, 0.0);
1945				vec4 ambient_accum = vec4(0.0, 0.0, 0.0, 0.0);
1946		
1947				uint reflection_indices = instances.data[draw_call.instance_index].reflection_probes.x;
1948		
1949		#ifdef LIGHT_ANISOTROPY_USED
1950				// https://google.github.io/filament/Filament.html#lighting/imagebasedlights/anisotropy
1951				vec3 anisotropic_direction = anisotropy >= 0.0 ? binormal : tangent;
1952				vec3 anisotropic_tangent = cross(anisotropic_direction, view);
1953				vec3 anisotropic_normal = cross(anisotropic_tangent, anisotropic_direction);
1954				vec3 bent_normal = normalize(mix(normal, anisotropic_normal, abs(anisotropy) * clamp(5.0 * roughness, 0.0, 1.0)));
1955		#else
1956				vec3 bent_normal = normal;
1957		#endif
1958				vec3 ref_vec = normalize(reflect(-view, bent_normal));
1959				ref_vec = mix(ref_vec, bent_normal, roughness * roughness);
1960		
1961				for (uint i = 0; i < 8; i++) {
1962					uint reflection_index = reflection_indices & 0xFF;
1963					if (i == 3) {
1964						reflection_indices = instances.data[draw_call.instance_index].reflection_probes.y;
1965					} else {
1966						reflection_indices = reflection_indices >> 8;
1967					}
1968		
1969					if (reflection_index == 0xFF) {
1970						break;
1971					}
1972		
1973					reflection_process(reflection_index, vertex, ref_vec, bent_normal, roughness, ambient_light, specular_light, ambient_accum, reflection_accum);
1974				}
1975		
1976				if (reflection_accum.a > 0.0) {
1977					specular_light = reflection_accum.rgb / reflection_accum.a;
1978				}
1979		
1980		#if !defined(USE_LIGHTMAP)
1981				if (ambient_accum.a > 0.0) {
1982					ambient_light = ambient_accum.rgb / ambient_accum.a;
1983				}
1984		#endif
1985			} //Reflection probes
1986		
1987			// finalize ambient light here
1988			{
1989		#if defined(AMBIENT_LIGHT_DISABLED)
1990				ambient_light = vec3(0.0, 0.0, 0.0);
1991		#else
1992				ambient_light *= albedo.rgb;
1993				ambient_light *= ao;
1994		#endif // AMBIENT_LIGHT_DISABLED
1995			}
1996		
1997			// convert ao to direct light ao
1998			ao = mix(1.0, ao, ao_light_affect);
1999		
2000			//this saves some VGPRs
2001			vec3 f0 = F0(metallic, specular, albedo);
2002		
2003			{
2004		#if defined(DIFFUSE_TOON)
2005				//simplify for toon, as
2006				specular_light *= specular * metallic * albedo * 2.0;
2007		#else
2008		
2009				// scales the specular reflections, needs to be computed before lighting happens,
2010				// but after environment, GI, and reflection probes are added
2011				// Environment brdf approximation (Lazarov 2013)
2012				// see https://www.unrealengine.com/en-US/blog/physically-based-shading-on-mobile
2013				const vec4 c0 = vec4(-1.0, -0.0275, -0.572, 0.022);
2014				const vec4 c1 = vec4(1.0, 0.0425, 1.04, -0.04);
2015				vec4 r = roughness * c0 + c1;
2016				float ndotv = clamp(dot(normal, view), 0.0, 1.0);
2017				float a004 = min(r.x * r.x, exp2(-9.28 * ndotv)) * r.x + r.y;
2018				vec2 env = vec2(-1.04, 1.04) * a004 + r.zw;
2019		
2020				specular_light *= env.x * f0 + env.y * clamp(50.0 * f0.g, metallic, 1.0);
2021		#endif
2022			}
2023		
2024		#endif // !defined(MODE_RENDER_DEPTH) && !defined(MODE_UNSHADED)
2025		
2026		#if !defined(MODE_RENDER_DEPTH)
2027			//this saves some VGPRs
2028			uint orms = packUnorm4x8(vec4(ao, roughness, metallic, specular));
2029		#endif
2030		
2031		// LIGHTING
2032		#if !defined(MODE_RENDER_DEPTH) && !defined(MODE_UNSHADED)
2033		
2034			if (!sc_disable_directional_lights) { //directional light
2035		#ifndef SHADOWS_DISABLED
2036				// Do shadow and lighting in two passes to reduce register pressure
2037				uint shadow0 = 0;
2038				uint shadow1 = 0;
2039		
2040				for (uint i = 0; i < 8; i++) {
2041					if (i >= scene_data.directional_light_count) {
2042						break;
2043					}
2044		
2045					if (!bool(directional_lights.data[i].mask & instances.data[draw_call.instance_index].layer_mask)) {
2046						continue; //not masked
2047					}
2048		
2049					float shadow = 1.0;
2050		
2051					// Directional light shadow code is basically the same as forward clustered at this point in time minus `LIGHT_TRANSMITTANCE_USED` support.
2052					// Not sure if there is a reason to change this seeing directional lights are part of our global data
2053					// Should think about whether we may want to move this code into an include file or function??
2054		
2055		#ifdef USE_SOFT_SHADOWS
2056					//version with soft shadows, more expensive
2057					if (directional_lights.data[i].shadow_opacity > 0.001) {
2058						float depth_z = -vertex.z;
2059		
2060						vec4 pssm_coord;
2061						vec3 light_dir = directional_lights.data[i].direction;
2062		
2063		#define BIAS_FUNC(m_var, m_idx)                                                                                                                                       \
2064			m_var.xyz += light_dir * directional_lights.data[i].shadow_bias[m_idx];                                                                                           \
2065			vec3 normal_bias = normalize(normal_interp) * (1.0 - max(0.0, dot(light_dir, -normalize(normal_interp)))) * directional_lights.data[i].shadow_normal_bias[m_idx]; \
2066			normal_bias -= light_dir * dot(light_dir, normal_bias);                                                                                                           \
2067			m_var.xyz += normal_bias;
2068		
2069						if (depth_z < directional_lights.data[i].shadow_split_offsets.x) {
2070							vec4 v = vec4(vertex, 1.0);
2071		
2072							BIAS_FUNC(v, 0)
2073		
2074							pssm_coord = (directional_lights.data[i].shadow_matrix1 * v);
2075							pssm_coord /= pssm_coord.w;
2076		
2077							if (directional_lights.data[i].softshadow_angle > 0) {
2078								float range_pos = dot(directional_lights.data[i].direction, v.xyz);
2079								float range_begin = directional_lights.data[i].shadow_range_begin.x;
2080								float test_radius = (range_pos - range_begin) * directional_lights.data[i].softshadow_angle;
2081								vec2 tex_scale = directional_lights.data[i].uv_scale1 * test_radius;
2082								shadow = sample_directional_soft_shadow(directional_shadow_atlas, pssm_coord.xyz, tex_scale * directional_lights.data[i].soft_shadow_scale);
2083							} else {
2084								shadow = sample_directional_pcf_shadow(directional_shadow_atlas, scene_data.directional_shadow_pixel_size * directional_lights.data[i].soft_shadow_scale, pssm_coord);
2085							}
2086						} else if (depth_z < directional_lights.data[i].shadow_split_offsets.y) {
2087							vec4 v = vec4(vertex, 1.0);
2088		
2089							BIAS_FUNC(v, 1)
2090		
2091							pssm_coord = (directional_lights.data[i].shadow_matrix2 * v);
2092							pssm_coord /= pssm_coord.w;
2093		
2094							if (directional_lights.data[i].softshadow_angle > 0) {
2095								float range_pos = dot(directional_lights.data[i].direction, v.xyz);
2096								float range_begin = directional_lights.data[i].shadow_range_begin.y;
2097								float test_radius = (range_pos - range_begin) * directional_lights.data[i].softshadow_angle;
2098								vec2 tex_scale = directional_lights.data[i].uv_scale2 * test_radius;
2099								shadow = sample_directional_soft_shadow(directional_shadow_atlas, pssm_coord.xyz, tex_scale * directional_lights.data[i].soft_shadow_scale);
2100							} else {
2101								shadow = sample_directional_pcf_shadow(directional_shadow_atlas, scene_data.directional_shadow_pixel_size * directional_lights.data[i].soft_shadow_scale, pssm_coord);
2102							}
2103						} else if (depth_z < directional_lights.data[i].shadow_split_offsets.z) {
2104							vec4 v = vec4(vertex, 1.0);
2105		
2106							BIAS_FUNC(v, 2)
2107		
2108							pssm_coord = (directional_lights.data[i].shadow_matrix3 * v);
2109							pssm_coord /= pssm_coord.w;
2110		
2111							if (directional_lights.data[i].softshadow_angle > 0) {
2112								float range_pos = dot(directional_lights.data[i].direction, v.xyz);
2113								float range_begin = directional_lights.data[i].shadow_range_begin.z;
2114								float test_radius = (range_pos - range_begin) * directional_lights.data[i].softshadow_angle;
2115								vec2 tex_scale = directional_lights.data[i].uv_scale3 * test_radius;
2116								shadow = sample_directional_soft_shadow(directional_shadow_atlas, pssm_coord.xyz, tex_scale * directional_lights.data[i].soft_shadow_scale);
2117							} else {
2118								shadow = sample_directional_pcf_shadow(directional_shadow_atlas, scene_data.directional_shadow_pixel_size * directional_lights.data[i].soft_shadow_scale, pssm_coord);
2119							}
2120						} else {
2121							vec4 v = vec4(vertex, 1.0);
2122		
2123							BIAS_FUNC(v, 3)
2124		
2125							pssm_coord = (directional_lights.data[i].shadow_matrix4 * v);
2126							pssm_coord /= pssm_coord.w;
2127		
2128							if (directional_lights.data[i].softshadow_angle > 0) {
2129								float range_pos = dot(directional_lights.data[i].direction, v.xyz);
2130								float range_begin = directional_lights.data[i].shadow_range_begin.w;
2131								float test_radius = (range_pos - range_begin) * directional_lights.data[i].softshadow_angle;
2132								vec2 tex_scale = directional_lights.data[i].uv_scale4 * test_radius;
2133								shadow = sample_directional_soft_shadow(directional_shadow_atlas, pssm_coord.xyz, tex_scale * directional_lights.data[i].soft_shadow_scale);
2134							} else {
2135								shadow = sample_directional_pcf_shadow(directional_shadow_atlas, scene_data.directional_shadow_pixel_size * directional_lights.data[i].soft_shadow_scale, pssm_coord);
2136							}
2137						}
2138		
2139						if (directional_lights.data[i].blend_splits) {
2140							float pssm_blend;
2141							float shadow2;
2142		
2143							if (depth_z < directional_lights.data[i].shadow_split_offsets.x) {
2144								vec4 v = vec4(vertex, 1.0);
2145								BIAS_FUNC(v, 1)
2146								pssm_coord = (directional_lights.data[i].shadow_matrix2 * v);
2147								pssm_coord /= pssm_coord.w;
2148		
2149								if (directional_lights.data[i].softshadow_angle > 0) {
2150									float range_pos = dot(directional_lights.data[i].direction, v.xyz);
2151									float range_begin = directional_lights.data[i].shadow_range_begin.y;
2152									float test_radius = (range_pos - range_begin) * directional_lights.data[i].softshadow_angle;
2153									vec2 tex_scale = directional_lights.data[i].uv_scale2 * test_radius;
2154									shadow2 = sample_directional_soft_shadow(directional_shadow_atlas, pssm_coord.xyz, tex_scale * directional_lights.data[i].soft_shadow_scale);
2155								} else {
2156									shadow2 = sample_directional_pcf_shadow(directional_shadow_atlas, scene_data.directional_shadow_pixel_size * directional_lights.data[i].soft_shadow_scale, pssm_coord);
2157								}
2158		
2159								pssm_blend = smoothstep(0.0, directional_lights.data[i].shadow_split_offsets.x, depth_z);
2160							} else if (depth_z < directional_lights.data[i].shadow_split_offsets.y) {
2161								vec4 v = vec4(vertex, 1.0);
2162								BIAS_FUNC(v, 2)
2163								pssm_coord = (directional_lights.data[i].shadow_matrix3 * v);
2164								pssm_coord /= pssm_coord.w;
2165		
2166								if (directional_lights.data[i].softshadow_angle > 0) {
2167									float range_pos = dot(directional_lights.data[i].direction, v.xyz);
2168									float range_begin = directional_lights.data[i].shadow_range_begin.z;
2169									float test_radius = (range_pos - range_begin) * directional_lights.data[i].softshadow_angle;
2170									vec2 tex_scale = directional_lights.data[i].uv_scale3 * test_radius;
2171									shadow2 = sample_directional_soft_shadow(directional_shadow_atlas, pssm_coord.xyz, tex_scale * directional_lights.data[i].soft_shadow_scale);
2172								} else {
2173									shadow2 = sample_directional_pcf_shadow(directional_shadow_atlas, scene_data.directional_shadow_pixel_size * directional_lights.data[i].soft_shadow_scale, pssm_coord);
2174								}
2175		
2176								pssm_blend = smoothstep(directional_lights.data[i].shadow_split_offsets.x, directional_lights.data[i].shadow_split_offsets.y, depth_z);
2177							} else if (depth_z < directional_lights.data[i].shadow_split_offsets.z) {
2178								vec4 v = vec4(vertex, 1.0);
2179								BIAS_FUNC(v, 3)
2180								pssm_coord = (directional_lights.data[i].shadow_matrix4 * v);
2181								pssm_coord /= pssm_coord.w;
2182								if (directional_lights.data[i].softshadow_angle > 0) {
2183									float range_pos = dot(directional_lights.data[i].direction, v.xyz);
2184									float range_begin = directional_lights.data[i].shadow_range_begin.w;
2185									float test_radius = (range_pos - range_begin) * directional_lights.data[i].softshadow_angle;
2186									vec2 tex_scale = directional_lights.data[i].uv_scale4 * test_radius;
2187									shadow2 = sample_directional_soft_shadow(directional_shadow_atlas, pssm_coord.xyz, tex_scale * directional_lights.data[i].soft_shadow_scale);
2188								} else {
2189									shadow2 = sample_directional_pcf_shadow(directional_shadow_atlas, scene_data.directional_shadow_pixel_size * directional_lights.data[i].soft_shadow_scale, pssm_coord);
2190								}
2191		
2192								pssm_blend = smoothstep(directional_lights.data[i].shadow_split_offsets.y, directional_lights.data[i].shadow_split_offsets.z, depth_z);
2193							} else {
2194								pssm_blend = 0.0; //if no blend, same coord will be used (divide by z will result in same value, and already cached)
2195							}
2196		
2197							pssm_blend = sqrt(pssm_blend);
2198		
2199							shadow = mix(shadow, shadow2, pssm_blend);
2200						}
2201		
2202						shadow = mix(shadow, 1.0, smoothstep(directional_lights.data[i].fade_from, directional_lights.data[i].fade_to, vertex.z)); //done with negative values for performance
2203		
2204		#undef BIAS_FUNC
2205					}
2206		#else
2207					// Soft shadow disabled version
2208		
2209					if (directional_lights.data[i].shadow_opacity > 0.001) {
2210						float depth_z = -vertex.z;
2211		
2212						vec4 pssm_coord;
2213						float blur_factor;
2214						vec3 light_dir = directional_lights.data[i].direction;
2215						vec3 base_normal_bias = normalize(normal_interp) * (1.0 - max(0.0, dot(light_dir, -normalize(normal_interp))));
2216		
2217		#define BIAS_FUNC(m_var, m_idx)                                                                 \
2218			m_var.xyz += light_dir * directional_lights.data[i].shadow_bias[m_idx];                     \
2219			vec3 normal_bias = base_normal_bias * directional_lights.data[i].shadow_normal_bias[m_idx]; \
2220			normal_bias -= light_dir * dot(light_dir, normal_bias);                                     \
2221			m_var.xyz += normal_bias;
2222		
2223						if (depth_z < directional_lights.data[i].shadow_split_offsets.x) {
2224							vec4 v = vec4(vertex, 1.0);
2225		
2226							BIAS_FUNC(v, 0)
2227		
2228							pssm_coord = (directional_lights.data[i].shadow_matrix1 * v);
2229							blur_factor = 1.0;
2230						} else if (depth_z < directional_lights.data[i].shadow_split_offsets.y) {
2231							vec4 v = vec4(vertex, 1.0);
2232		
2233							BIAS_FUNC(v, 1)
2234		
2235							pssm_coord = (directional_lights.data[i].shadow_matrix2 * v);
2236							// Adjust shadow blur with reference to the first split to reduce discrepancy between shadow splits.
2237							blur_factor = directional_lights.data[i].shadow_split_offsets.x / directional_lights.data[i].shadow_split_offsets.y;
2238							;
2239						} else if (depth_z < directional_lights.data[i].shadow_split_offsets.z) {
2240							vec4 v = vec4(vertex, 1.0);
2241		
2242							BIAS_FUNC(v, 2)
2243		
2244							pssm_coord = (directional_lights.data[i].shadow_matrix3 * v);
2245							// Adjust shadow blur with reference to the first split to reduce discrepancy between shadow splits.
2246							blur_factor = directional_lights.data[i].shadow_split_offsets.x / directional_lights.data[i].shadow_split_offsets.z;
2247						} else {
2248							vec4 v = vec4(vertex, 1.0);
2249		
2250							BIAS_FUNC(v, 3)
2251		
2252							pssm_coord = (directional_lights.data[i].shadow_matrix4 * v);
2253							// Adjust shadow blur with reference to the first split to reduce discrepancy between shadow splits.
2254							blur_factor = directional_lights.data[i].shadow_split_offsets.x / directional_lights.data[i].shadow_split_offsets.w;
2255						}
2256		
2257						pssm_coord /= pssm_coord.w;
2258		
2259						shadow = sample_directional_pcf_shadow(directional_shadow_atlas, scene_data.directional_shadow_pixel_size * directional_lights.data[i].soft_shadow_scale * blur_factor, pssm_coord);
2260		
2261						if (directional_lights.data[i].blend_splits) {
2262							float pssm_blend;
2263							float blur_factor2;
2264		
2265							if (depth_z < directional_lights.data[i].shadow_split_offsets.x) {
2266								vec4 v = vec4(vertex, 1.0);
2267								BIAS_FUNC(v, 1)
2268								pssm_coord = (directional_lights.data[i].shadow_matrix2 * v);
2269								pssm_blend = smoothstep(0.0, directional_lights.data[i].shadow_split_offsets.x, depth_z);
2270								// Adjust shadow blur with reference to the first split to reduce discrepancy between shadow splits.
2271								blur_factor2 = directional_lights.data[i].shadow_split_offsets.x / directional_lights.data[i].shadow_split_offsets.y;
2272							} else if (depth_z < directional_lights.data[i].shadow_split_offsets.y) {
2273								vec4 v = vec4(vertex, 1.0);
2274								BIAS_FUNC(v, 2)
2275								pssm_coord = (directional_lights.data[i].shadow_matrix3 * v);
2276								pssm_blend = smoothstep(directional_lights.data[i].shadow_split_offsets.x, directional_lights.data[i].shadow_split_offsets.y, depth_z);
2277								// Adjust shadow blur with reference to the first split to reduce discrepancy between shadow splits.
2278								blur_factor2 = directional_lights.data[i].shadow_split_offsets.x / directional_lights.data[i].shadow_split_offsets.z;
2279							} else if (depth_z < directional_lights.data[i].shadow_split_offsets.z) {
2280								vec4 v = vec4(vertex, 1.0);
2281								BIAS_FUNC(v, 3)
2282								pssm_coord = (directional_lights.data[i].shadow_matrix4 * v);
2283								pssm_blend = smoothstep(directional_lights.data[i].shadow_split_offsets.y, directional_lights.data[i].shadow_split_offsets.z, depth_z);
2284								// Adjust shadow blur with reference to the first split to reduce discrepancy between shadow splits.
2285								blur_factor2 = directional_lights.data[i].shadow_split_offsets.x / directional_lights.data[i].shadow_split_offsets.w;
2286							} else {
2287								pssm_blend = 0.0; //if no blend, same coord will be used (divide by z will result in same value, and already cached)
2288								blur_factor2 = 1.0;
2289							}
2290		
2291							pssm_coord /= pssm_coord.w;
2292		
2293							float shadow2 = sample_directional_pcf_shadow(directional_shadow_atlas, scene_data.directional_shadow_pixel_size * directional_lights.data[i].soft_shadow_scale * blur_factor2, pssm_coord);
2294							shadow = mix(shadow, shadow2, pssm_blend);
2295						}
2296		
2297						shadow = mix(shadow, 1.0, smoothstep(directional_lights.data[i].fade_from, directional_lights.data[i].fade_to, vertex.z)); //done with negative values for performance
2298		
2299		#undef BIAS_FUNC
2300					}
2301		#endif
2302		
2303					if (i < 4) {
2304						shadow0 |= uint(clamp(shadow * 255.0, 0.0, 255.0)) << (i * 8);
2305					} else {
2306						shadow1 |= uint(clamp(shadow * 255.0, 0.0, 255.0)) << ((i - 4) * 8);
2307					}
2308				}
2309		
2310		#endif // SHADOWS_DISABLED
2311		
2312				for (uint i = 0; i < 8; i++) {
2313					if (i >= scene_data.directional_light_count) {
2314						break;
2315					}
2316		
2317					if (!bool(directional_lights.data[i].mask & instances.data[draw_call.instance_index].layer_mask)) {
2318						continue; //not masked
2319					}
2320		
2321					// We're not doing light transmittence
2322		
2323					float shadow = 1.0;
2324		#ifndef SHADOWS_DISABLED
2325					if (i < 4) {
2326						shadow = float(shadow0 >> (i * 8) & 0xFF) / 255.0;
2327					} else {
2328						shadow = float(shadow1 >> ((i - 4) * 8) & 0xFF) / 255.0;
2329					}
2330		
2331					shadow = mix(1.0, shadow, directional_lights.data[i].shadow_opacity);
2332		#endif
2333					blur_shadow(shadow);
2334		
2335		#ifdef DEBUG_DRAW_PSSM_SPLITS
2336					vec3 tint = vec3(1.0);
2337					if (-vertex.z < directional_lights.data[i].shadow_split_offsets.x) {
2338						tint = vec3(1.0, 0.0, 0.0);
2339					} else if (-vertex.z < directional_lights.data[i].shadow_split_offsets.y) {
2340						tint = vec3(0.0, 1.0, 0.0);
2341					} else if (-vertex.z < directional_lights.data[i].shadow_split_offsets.z) {
2342						tint = vec3(0.0, 0.0, 1.0);
2343					} else {
2344						tint = vec3(1.0, 1.0, 0.0);
2345					}
2346					tint = mix(tint, vec3(1.0), shadow);
2347					shadow = 1.0;
2348		#endif
2349		
2350					light_compute(normal, directional_lights.data[i].direction, normalize(view), 0.0,
2351		#ifndef DEBUG_DRAW_PSSM_SPLITS
2352							directional_lights.data[i].color * directional_lights.data[i].energy,
2353		#else
2354							directional_lights.data[i].color * directional_lights.data[i].energy * tint,
2355		#endif
2356							true, shadow, f0, orms, 1.0, albedo, alpha,
2357		#ifdef LIGHT_BACKLIGHT_USED
2358							backlight,
2359		#endif
2360		/* not supported here
2361		#ifdef LIGHT_TRANSMITTANCE_USED
2362							transmittance_color,
2363							transmittance_depth,
2364							transmittance_boost,
2365							transmittance_z,
2366		#endif
2367		*/
2368		#ifdef LIGHT_RIM_USED
2369							rim, rim_tint,
2370		#endif
2371		#ifdef LIGHT_CLEARCOAT_USED
2372							clearcoat, clearcoat_roughness, normalize(normal_interp),
2373		#endif
2374		#ifdef LIGHT_ANISOTROPY_USED
2375							binormal, tangent, anisotropy,
2376		#endif
2377		#ifdef USE_SOFT_SHADOW
2378							directional_lights.data[i].size,
2379		#endif
2380							diffuse_light,
2381							specular_light);
2382				}
2383			} //directional light
2384		
2385			if (!sc_disable_omni_lights) { //omni lights
2386				uint light_indices = instances.data[draw_call.instance_index].omni_lights.x;
2387				for (uint i = 0; i < 8; i++) {
2388					uint light_index = light_indices & 0xFF;
2389					if (i == 3) {
2390						light_indices = instances.data[draw_call.instance_index].omni_lights.y;
2391					} else {
2392						light_indices = light_indices >> 8;
2393					}
2394		
2395					if (light_index == 0xFF) {
2396						break;
2397					}
2398		
2399					float shadow = light_process_omni_shadow(light_index, vertex, normal);
2400		
2401					shadow = blur_shadow(shadow);
2402		
2403					light_process_omni(light_index, vertex, view, normal, vertex_ddx, vertex_ddy, f0, orms, shadow, albedo, alpha,
2404		#ifdef LIGHT_BACKLIGHT_USED
2405							backlight,
2406		#endif
2407		/*
2408		#ifdef LIGHT_TRANSMITTANCE_USED
2409							transmittance_color,
2410							transmittance_depth,
2411							transmittance_boost,
2412		#endif
2413		*/
2414		#ifdef LIGHT_RIM_USED
2415							rim,
2416							rim_tint,
2417		#endif
2418		#ifdef LIGHT_CLEARCOAT_USED
2419							clearcoat, clearcoat_roughness, normalize(normal_interp),
2420		#endif
2421		#ifdef LIGHT_ANISOTROPY_USED
2422							tangent,
2423							binormal, anisotropy,
2424		#endif
2425							diffuse_light, specular_light);
2426				}
2427			} //omni lights
2428		
2429			if (!sc_disable_spot_lights) { //spot lights
2430		
2431				uint light_indices = instances.data[draw_call.instance_index].spot_lights.x;
2432				for (uint i = 0; i < 8; i++) {
2433					uint light_index = light_indices & 0xFF;
2434					if (i == 3) {
2435						light_indices = instances.data[draw_call.instance_index].spot_lights.y;
2436					} else {
2437						light_indices = light_indices >> 8;
2438					}
2439		
2440					if (light_index == 0xFF) {
2441						break;
2442					}
2443		
2444					float shadow = light_process_spot_shadow(light_index, vertex, normal);
2445		
2446					shadow = blur_shadow(shadow);
2447		
2448					light_process_spot(light_index, vertex, view, normal, vertex_ddx, vertex_ddy, f0, orms, shadow, albedo, alpha,
2449		#ifdef LIGHT_BACKLIGHT_USED
2450							backlight,
2451		#endif
2452		/*
2453		#ifdef LIGHT_TRANSMITTANCE_USED
2454							transmittance_color,
2455							transmittance_depth,
2456							transmittance_boost,
2457		#endif
2458		*/
2459		#ifdef LIGHT_RIM_USED
2460							rim,
2461							rim_tint,
2462		#endif
2463		#ifdef LIGHT_CLEARCOAT_USED
2464							clearcoat, clearcoat_roughness, normalize(normal_interp),
2465		#endif
2466		#ifdef LIGHT_ANISOTROPY_USED
2467							tangent,
2468							binormal, anisotropy,
2469		#endif
2470							diffuse_light, specular_light);
2471				}
2472			} //spot lights
2473		
2474		#ifdef USE_SHADOW_TO_OPACITY
2475			alpha = min(alpha, clamp(length(ambient_light), 0.0, 1.0));
2476		
2477		#if defined(ALPHA_SCISSOR_USED)
2478			if (alpha < alpha_scissor) {
2479				discard;
2480			}
2481		#else
2482		#ifdef MODE_RENDER_DEPTH
2483		#ifdef USE_OPAQUE_PREPASS
2484		
2485			if (alpha < scene_data.opaque_prepass_threshold) {
2486				discard;
2487			}
2488		
2489		#endif // USE_OPAQUE_PREPASS
2490		#endif // MODE_RENDER_DEPTH
2491		#endif // !ALPHA_SCISSOR_USED
2492		
2493		#endif // USE_SHADOW_TO_OPACITY
2494		
2495		#endif //!defined(MODE_RENDER_DEPTH) && !defined(MODE_UNSHADED)
2496		
2497		#ifdef MODE_RENDER_DEPTH
2498		
2499		#ifdef MODE_RENDER_MATERIAL
2500		
2501			albedo_output_buffer.rgb = albedo;
2502			albedo_output_buffer.a = alpha;
2503		
2504			normal_output_buffer.rgb = normal * 0.5 + 0.5;
2505			normal_output_buffer.a = 0.0;
2506			depth_output_buffer.r = -vertex.z;
2507		
2508			orm_output_buffer.r = ao;
2509			orm_output_buffer.g = roughness;
2510			orm_output_buffer.b = metallic;
2511			orm_output_buffer.a = sss_strength;
2512		
2513			emission_output_buffer.rgb = emission;
2514			emission_output_buffer.a = 0.0;
2515		#endif // MODE_RENDER_MATERIAL
2516		
2517		#else // MODE_RENDER_DEPTH
2518		
2519			// multiply by albedo
2520			diffuse_light *= albedo; // ambient must be multiplied by albedo at the end
2521		
2522			// apply direct light AO
2523			ao = unpackUnorm4x8(orms).x;
2524			specular_light *= ao;
2525			diffuse_light *= ao;
2526		
2527			// apply metallic
2528			metallic = unpackUnorm4x8(orms).z;
2529			diffuse_light *= 1.0 - metallic;
2530			ambient_light *= 1.0 - metallic;
2531		
2532		#ifndef FOG_DISABLED
2533			//restore fog
2534			fog = vec4(unpackHalf2x16(fog_rg), unpackHalf2x16(fog_ba));
2535		#endif // !FOG_DISABLED
2536		
2537		#ifdef MODE_MULTIPLE_RENDER_TARGETS
2538		
2539		#ifdef MODE_UNSHADED
2540			diffuse_buffer = vec4(albedo.rgb, 0.0);
2541			specular_buffer = vec4(0.0);
2542		
2543		#else // MODE_UNSHADED
2544		
2545		#ifdef SSS_MODE_SKIN
2546			sss_strength = -sss_strength;
2547		#endif // SSS_MODE_SKIN
2548			diffuse_buffer = vec4(emission + diffuse_light + ambient_light, sss_strength);
2549			specular_buffer = vec4(specular_light, metallic);
2550		#endif // MODE_UNSHADED
2551		
2552		#ifndef FOG_DISABLED
2553			diffuse_buffer.rgb = mix(diffuse_buffer.rgb, fog.rgb, fog.a);
2554			specular_buffer.rgb = mix(specular_buffer.rgb, vec3(0.0), fog.a);
2555		#endif // !FOG_DISABLED
2556		
2557		#else //MODE_MULTIPLE_RENDER_TARGETS
2558		
2559		#ifdef MODE_UNSHADED
2560			frag_color = vec4(albedo, alpha);
2561		#else // MODE_UNSHADED
2562			frag_color = vec4(emission + ambient_light + diffuse_light + specular_light, alpha);
2563		#endif // MODE_UNSHADED
2564		
2565		#ifndef FOG_DISABLED
2566			// Draw "fixed" fog before volumetric fog to ensure volumetric fog can appear in front of the sky.
2567			frag_color.rgb = mix(frag_color.rgb, fog.rgb, fog.a);
2568		#endif // !FOG_DISABLED
2569		
2570			// On mobile we use a UNORM buffer with 10bpp which results in a range from 0.0 - 1.0 resulting in HDR breaking
2571			// We divide by sc_luminance_multiplier to support a range from 0.0 - 2.0 both increasing precision on bright and darker images
2572			frag_color.rgb = frag_color.rgb / sc_luminance_multiplier;
2573		
2574		#endif //MODE_MULTIPLE_RENDER_TARGETS
2575		
2576		#endif //MODE_RENDER_DEPTH
2577		}
2578		
2579		
          RDShaderFile                                    RSRC