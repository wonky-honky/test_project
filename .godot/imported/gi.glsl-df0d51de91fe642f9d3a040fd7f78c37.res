RSRC                    RDShaderFile            ��������                                                  resource_local_to_scene    resource_name    bytecode_vertex    bytecode_fragment    bytecode_tesselation_control     bytecode_tesselation_evaluation    bytecode_compute    compile_error_vertex    compile_error_fragment "   compile_error_tesselation_control %   compile_error_tesselation_evaluation    compile_error_compute    script 
   _versions    base_error           local://RDShaderSPIRV_i5g0i ;         local://RDShaderFile_45sfm &r         RDShaderSPIRV          �o  Failed parse:
ERROR: 0:203: 'SDFGI_OCT_SIZE' : undeclared identifier 
ERROR: 0:203: '' : compilation terminated 
ERROR: 2 compilation errors.  No code generated.




Stage 'compute' source code: 

1		
2		#version 450
3		
4		#
5		
6		#ifdef SAMPLE_VOXEL_GI_NEAREST
7		#extension GL_EXT_samplerless_texture_functions : enable
8		#endif
9		
10		layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
11		
12		#define M_PI 3.141592
13		
14		/* Specialization Constants (Toggles) */
15		
16		layout(constant_id = 0) const bool sc_half_res = false;
17		layout(constant_id = 1) const bool sc_use_full_projection_matrix = false;
18		layout(constant_id = 2) const bool sc_use_vrs = false;
19		
20		#define SDFGI_MAX_CASCADES 8
21		
22		//set 0 for SDFGI and render buffers
23		
24		layout(set = 0, binding = 1) uniform texture3D sdf_cascades[SDFGI_MAX_CASCADES];
25		layout(set = 0, binding = 2) uniform texture3D light_cascades[SDFGI_MAX_CASCADES];
26		layout(set = 0, binding = 3) uniform texture3D aniso0_cascades[SDFGI_MAX_CASCADES];
27		layout(set = 0, binding = 4) uniform texture3D aniso1_cascades[SDFGI_MAX_CASCADES];
28		layout(set = 0, binding = 5) uniform texture3D occlusion_texture;
29		
30		layout(set = 0, binding = 6) uniform sampler linear_sampler;
31		layout(set = 0, binding = 7) uniform sampler linear_sampler_with_mipmaps;
32		
33		struct ProbeCascadeData {
34			vec3 position;
35			float to_probe;
36			ivec3 probe_world_offset;
37			float to_cell; // 1/bounds * grid_size
38			vec3 pad;
39			float exposure_normalization;
40		};
41		
42		layout(rgba16f, set = 0, binding = 9) uniform restrict writeonly image2D ambient_buffer;
43		layout(rgba16f, set = 0, binding = 10) uniform restrict writeonly image2D reflection_buffer;
44		
45		layout(set = 0, binding = 11) uniform texture2DArray lightprobe_texture;
46		
47		layout(set = 0, binding = 12) uniform texture2D depth_buffer;
48		layout(set = 0, binding = 13) uniform texture2D normal_roughness_buffer;
49		layout(set = 0, binding = 14) uniform utexture2D voxel_gi_buffer;
50		
51		layout(set = 0, binding = 15, std140) uniform SDFGI {
52			vec3 grid_size;
53			uint max_cascades;
54		
55			bool use_occlusion;
56			int probe_axis_size;
57			float probe_to_uvw;
58			float normal_bias;
59		
60			vec3 lightprobe_tex_pixel_size;
61			float energy;
62		
63			vec3 lightprobe_uv_offset;
64			float y_mult;
65		
66			vec3 occlusion_clamp;
67			uint pad3;
68		
69			vec3 occlusion_renormalize;
70			uint pad4;
71		
72			vec3 cascade_probe_size;
73			uint pad5;
74		
75			ProbeCascadeData cascades[SDFGI_MAX_CASCADES];
76		}
77		sdfgi;
78		
79		#define MAX_VOXEL_GI_INSTANCES 8
80		
81		struct VoxelGIData {
82			mat4 xform; // 64 - 64
83		
84			vec3 bounds; // 12 - 76
85			float dynamic_range; // 4 - 80
86		
87			float bias; // 4 - 84
88			float normal_bias; // 4 - 88
89			bool blend_ambient; // 4 - 92
90			uint mipmaps; // 4 - 96
91		
92			vec3 pad; // 12 - 108
93			float exposure_normalization; // 4 - 112
94		};
95		
96		layout(set = 0, binding = 16, std140) uniform VoxelGIs {
97			VoxelGIData data[MAX_VOXEL_GI_INSTANCES];
98		}
99		voxel_gi_instances;
100		
101		layout(set = 0, binding = 17) uniform texture3D voxel_gi_textures[MAX_VOXEL_GI_INSTANCES];
102		
103		layout(set = 0, binding = 18, std140) uniform SceneData {
104			mat4x4 inv_projection[2];
105			mat4x4 cam_transform;
106			vec4 eye_offset[2];
107		
108			ivec2 screen_size;
109			float pad1;
110			float pad2;
111		}
112		scene_data;
113		
114		#ifdef USE_VRS
115		layout(r8ui, set = 0, binding = 19) uniform restrict readonly uimage2D vrs_buffer;
116		#endif
117		
118		layout(push_constant, std430) uniform Params {
119			uint max_voxel_gi_instances;
120			bool high_quality_vct;
121			bool orthogonal;
122			uint view_index;
123		
124			vec4 proj_info;
125		
126			float z_near;
127			float z_far;
128			float pad2;
129			float pad3;
130		}
131		params;
132		
133		vec2 octahedron_wrap(vec2 v) {
134			vec2 signVal;
135			signVal.x = v.x >= 0.0 ? 1.0 : -1.0;
136			signVal.y = v.y >= 0.0 ? 1.0 : -1.0;
137			return (1.0 - abs(v.yx)) * signVal;
138		}
139		
140		vec2 octahedron_encode(vec3 n) {
141			// https://twitter.com/Stubbesaurus/status/937994790553227264
142			n /= (abs(n.x) + abs(n.y) + abs(n.z));
143			n.xy = n.z >= 0.0 ? n.xy : octahedron_wrap(n.xy);
144			n.xy = n.xy * 0.5 + 0.5;
145			return n.xy;
146		}
147		
148		vec4 blend_color(vec4 src, vec4 dst) {
149			vec4 res;
150			float sa = 1.0 - src.a;
151			res.a = dst.a * sa + src.a;
152			if (res.a == 0.0) {
153				res.rgb = vec3(0);
154			} else {
155				res.rgb = (dst.rgb * dst.a * sa + src.rgb * src.a) / res.a;
156			}
157			return res;
158		}
159		
160		vec3 reconstruct_position(ivec2 screen_pos) {
161			if (sc_use_full_projection_matrix) {
162				vec4 pos;
163				pos.xy = (2.0 * vec2(screen_pos) / vec2(scene_data.screen_size)) - 1.0;
164				pos.z = texelFetch(sampler2D(depth_buffer, linear_sampler), screen_pos, 0).r * 2.0 - 1.0;
165				pos.w = 1.0;
166		
167				pos = scene_data.inv_projection[params.view_index] * pos;
168		
169				return pos.xyz / pos.w;
170			} else {
171				vec3 pos;
172				pos.z = texelFetch(sampler2D(depth_buffer, linear_sampler), screen_pos, 0).r;
173		
174				pos.z = pos.z * 2.0 - 1.0;
175				if (params.orthogonal) {
176					pos.z = ((pos.z + (params.z_far + params.z_near) / (params.z_far - params.z_near)) * (params.z_far - params.z_near)) / 2.0;
177				} else {
178					pos.z = 2.0 * params.z_near * params.z_far / (params.z_far + params.z_near - pos.z * (params.z_far - params.z_near));
179				}
180				pos.z = -pos.z;
181		
182				pos.xy = vec2(screen_pos) * params.proj_info.xy + params.proj_info.zw;
183				if (!params.orthogonal) {
184					pos.xy *= pos.z;
185				}
186		
187				return pos;
188			}
189		}
190		
191		void sdfvoxel_gi_process(uint cascade, vec3 cascade_pos, vec3 cam_pos, vec3 cam_normal, vec3 cam_specular_normal, float roughness, out vec3 diffuse_light, out vec3 specular_light) {
192			cascade_pos += cam_normal * sdfgi.normal_bias;
193		
194			vec3 base_pos = floor(cascade_pos);
195			//cascade_pos += mix(vec3(0.0),vec3(0.01),lessThan(abs(cascade_pos-base_pos),vec3(0.01))) * cam_normal;
196			ivec3 probe_base_pos = ivec3(base_pos);
197		
198			vec4 diffuse_accum = vec4(0.0);
199			vec3 specular_accum;
200		
201			ivec3 tex_pos = ivec3(probe_base_pos.xy, int(cascade));
202			tex_pos.x += probe_base_pos.z * sdfgi.probe_axis_size;
203			tex_pos.xy = tex_pos.xy * (SDFGI_OCT_SIZE + 2) + ivec2(1);
204		
205			vec3 diffuse_posf = (vec3(tex_pos) + vec3(octahedron_encode(cam_normal) * float(SDFGI_OCT_SIZE), 0.0)) * sdfgi.lightprobe_tex_pixel_size;
206		
207			vec3 specular_posf = (vec3(tex_pos) + vec3(octahedron_encode(cam_specular_normal) * float(SDFGI_OCT_SIZE), 0.0)) * sdfgi.lightprobe_tex_pixel_size;
208		
209			specular_accum = vec3(0.0);
210		
211			vec4 light_accum = vec4(0.0);
212			float weight_accum = 0.0;
213		
214			for (uint j = 0; j < 8; j++) {
215				ivec3 offset = (ivec3(j) >> ivec3(0, 1, 2)) & ivec3(1, 1, 1);
216				ivec3 probe_posi = probe_base_pos;
217				probe_posi += offset;
218		
219				// Compute weight
220		
221				vec3 probe_pos = vec3(probe_posi);
222				vec3 probe_to_pos = cascade_pos - probe_pos;
223				vec3 probe_dir = normalize(-probe_to_pos);
224		
225				vec3 trilinear = vec3(1.0) - abs(probe_to_pos);
226				float weight = trilinear.x * trilinear.y * trilinear.z * max(0.005, dot(cam_normal, probe_dir));
227		
228				// Compute lightprobe occlusion
229		
230				if (sdfgi.use_occlusion) {
231					ivec3 occ_indexv = abs((sdfgi.cascades[cascade].probe_world_offset + probe_posi) & ivec3(1, 1, 1)) * ivec3(1, 2, 4);
232					vec4 occ_mask = mix(vec4(0.0), vec4(1.0), equal(ivec4(occ_indexv.x | occ_indexv.y), ivec4(0, 1, 2, 3)));
233		
234					vec3 occ_pos = clamp(cascade_pos, probe_pos - sdfgi.occlusion_clamp, probe_pos + sdfgi.occlusion_clamp) * sdfgi.probe_to_uvw;
235					occ_pos.z += float(cascade);
236					if (occ_indexv.z != 0) { //z bit is on, means index is >=4, so make it switch to the other half of textures
237						occ_pos.x += 1.0;
238					}
239		
240					occ_pos *= sdfgi.occlusion_renormalize;
241					float occlusion = dot(textureLod(sampler3D(occlusion_texture, linear_sampler), occ_pos, 0.0), occ_mask);
242		
243					weight *= max(occlusion, 0.01);
244				}
245		
246				// Compute lightprobe texture position
247		
248				vec3 diffuse;
249				vec3 pos_uvw = diffuse_posf;
250				pos_uvw.xy += vec2(offset.xy) * sdfgi.lightprobe_uv_offset.xy;
251				pos_uvw.x += float(offset.z) * sdfgi.lightprobe_uv_offset.z;
252				diffuse = textureLod(sampler2DArray(lightprobe_texture, linear_sampler), pos_uvw, 0.0).rgb;
253		
254				diffuse_accum += vec4(diffuse * weight * sdfgi.cascades[cascade].exposure_normalization, weight);
255		
256				{
257					vec3 specular = vec3(0.0);
258					vec3 pos_uvw = specular_posf;
259					pos_uvw.xy += vec2(offset.xy) * sdfgi.lightprobe_uv_offset.xy;
260					pos_uvw.x += float(offset.z) * sdfgi.lightprobe_uv_offset.z;
261					if (roughness < 0.99) {
262						specular = textureLod(sampler2DArray(lightprobe_texture, linear_sampler), pos_uvw + vec3(0, 0, float(sdfgi.max_cascades)), 0.0).rgb;
263					}
264					if (roughness > 0.2) {
265						specular = mix(specular, textureLod(sampler2DArray(lightprobe_texture, linear_sampler), pos_uvw, 0.0).rgb, (roughness - 0.2) * 1.25);
266					}
267		
268					specular_accum += specular * weight * sdfgi.cascades[cascade].exposure_normalization;
269				}
270			}
271		
272			if (diffuse_accum.a > 0.0) {
273				diffuse_accum.rgb /= diffuse_accum.a;
274			}
275		
276			diffuse_light = diffuse_accum.rgb;
277		
278			if (diffuse_accum.a > 0.0) {
279				specular_accum /= diffuse_accum.a;
280			}
281		
282			specular_light = specular_accum;
283		}
284		
285		void sdfgi_process(vec3 vertex, vec3 normal, vec3 reflection, float roughness, out vec4 ambient_light, out vec4 reflection_light) {
286			//make vertex orientation the world one, but still align to camera
287			vertex.y *= sdfgi.y_mult;
288			normal.y *= sdfgi.y_mult;
289			reflection.y *= sdfgi.y_mult;
290		
291			//renormalize
292			normal = normalize(normal);
293			reflection = normalize(reflection);
294		
295			vec3 cam_pos = vertex;
296			vec3 cam_normal = normal;
297		
298			vec4 light_accum = vec4(0.0);
299			float weight_accum = 0.0;
300		
301			vec4 light_blend_accum = vec4(0.0);
302			float weight_blend_accum = 0.0;
303		
304			float blend = -1.0;
305		
306			// helper constants, compute once
307		
308			uint cascade = 0xFFFFFFFF;
309			vec3 cascade_pos;
310			vec3 cascade_normal;
311		
312			for (uint i = 0; i < sdfgi.max_cascades; i++) {
313				cascade_pos = (cam_pos - sdfgi.cascades[i].position) * sdfgi.cascades[i].to_probe;
314		
315				if (any(lessThan(cascade_pos, vec3(0.0))) || any(greaterThanEqual(cascade_pos, sdfgi.cascade_probe_size))) {
316					continue; //skip cascade
317				}
318		
319				cascade = i;
320				break;
321			}
322		
323			if (cascade < SDFGI_MAX_CASCADES) {
324				ambient_light = vec4(0, 0, 0, 1);
325				reflection_light = vec4(0, 0, 0, 1);
326		
327				float blend;
328				vec3 diffuse, specular;
329				sdfvoxel_gi_process(cascade, cascade_pos, cam_pos, cam_normal, reflection, roughness, diffuse, specular);
330		
331				{
332					//process blend
333					float blend_from = (float(sdfgi.probe_axis_size - 1) / 2.0) - 2.5;
334					float blend_to = blend_from + 2.0;
335		
336					vec3 inner_pos = cam_pos * sdfgi.cascades[cascade].to_probe;
337		
338					float len = length(inner_pos);
339		
340					inner_pos = abs(normalize(inner_pos));
341					len *= max(inner_pos.x, max(inner_pos.y, inner_pos.z));
342		
343					if (len >= blend_from) {
344						blend = smoothstep(blend_from, blend_to, len);
345					} else {
346						blend = 0.0;
347					}
348				}
349		
350				if (blend > 0.0) {
351					//blend
352					if (cascade == sdfgi.max_cascades - 1) {
353						ambient_light.a = 1.0 - blend;
354						reflection_light.a = 1.0 - blend;
355		
356					} else {
357						vec3 diffuse2, specular2;
358						cascade_pos = (cam_pos - sdfgi.cascades[cascade + 1].position) * sdfgi.cascades[cascade + 1].to_probe;
359						sdfvoxel_gi_process(cascade + 1, cascade_pos, cam_pos, cam_normal, reflection, roughness, diffuse2, specular2);
360						diffuse = mix(diffuse, diffuse2, blend);
361						specular = mix(specular, specular2, blend);
362					}
363				}
364		
365				ambient_light.rgb = diffuse;
366		
367				if (roughness < 0.2) {
368					vec3 pos_to_uvw = 1.0 / sdfgi.grid_size;
369					vec4 light_accum = vec4(0.0);
370		
371					float blend_size = (sdfgi.grid_size.x / float(sdfgi.probe_axis_size - 1)) * 0.5;
372		
373					float radius_sizes[SDFGI_MAX_CASCADES];
374					cascade = 0xFFFF;
375		
376					float base_distance = length(cam_pos);
377					for (uint i = 0; i < sdfgi.max_cascades; i++) {
378						radius_sizes[i] = (1.0 / sdfgi.cascades[i].to_cell) * (sdfgi.grid_size.x * 0.5 - blend_size);
379						if (cascade == 0xFFFF && base_distance < radius_sizes[i]) {
380							cascade = i;
381						}
382					}
383		
384					cascade = min(cascade, sdfgi.max_cascades - 1);
385		
386					float max_distance = radius_sizes[sdfgi.max_cascades - 1];
387					vec3 ray_pos = cam_pos;
388					vec3 ray_dir = reflection;
389		
390					{
391						float prev_radius = cascade > 0 ? radius_sizes[cascade - 1] : 0.0;
392						float base_blend = (base_distance - prev_radius) / (radius_sizes[cascade] - prev_radius);
393						float bias = (1.0 + base_blend) * 1.1;
394						vec3 abs_ray_dir = abs(ray_dir);
395						//ray_pos += ray_dir * (bias / sdfgi.cascades[cascade].to_cell); //bias to avoid self occlusion
396						ray_pos += (ray_dir * 1.0 / max(abs_ray_dir.x, max(abs_ray_dir.y, abs_ray_dir.z)) + cam_normal * 1.4) * bias / sdfgi.cascades[cascade].to_cell;
397					}
398					float softness = 0.2 + min(1.0, roughness * 5.0) * 4.0; //approximation to roughness so it does not seem like a hard fade
399					uint i = 0;
400					bool found = false;
401					while (true) {
402						if (length(ray_pos) >= max_distance || light_accum.a > 0.99) {
403							break;
404						}
405						if (!found && i >= cascade && length(ray_pos) < radius_sizes[i]) {
406							uint next_i = min(i + 1, sdfgi.max_cascades - 1);
407							cascade = max(i, cascade); //never go down
408		
409							vec3 pos = ray_pos - sdfgi.cascades[i].position;
410							pos *= sdfgi.cascades[i].to_cell * pos_to_uvw;
411		
412							float fdistance = textureLod(sampler3D(sdf_cascades[i], linear_sampler), pos, 0.0).r * 255.0 - 1.1;
413		
414							vec4 hit_light = vec4(0.0);
415							if (fdistance < softness) {
416								hit_light.rgb = textureLod(sampler3D(light_cascades[i], linear_sampler), pos, 0.0).rgb;
417								hit_light.rgb *= 0.5; //approximation given value read is actually meant for anisotropy
418								hit_light.a = clamp(1.0 - (fdistance / softness), 0.0, 1.0);
419								hit_light.rgb *= hit_light.a;
420							}
421		
422							fdistance /= sdfgi.cascades[i].to_cell;
423		
424							if (i < (sdfgi.max_cascades - 1)) {
425								pos = ray_pos - sdfgi.cascades[next_i].position;
426								pos *= sdfgi.cascades[next_i].to_cell * pos_to_uvw;
427		
428								float fdistance2 = textureLod(sampler3D(sdf_cascades[next_i], linear_sampler), pos, 0.0).r * 255.0 - 1.1;
429		
430								vec4 hit_light2 = vec4(0.0);
431								if (fdistance2 < softness) {
432									hit_light2.rgb = textureLod(sampler3D(light_cascades[next_i], linear_sampler), pos, 0.0).rgb;
433									hit_light2.rgb *= 0.5; //approximation given value read is actually meant for anisotropy
434									hit_light2.a = clamp(1.0 - (fdistance2 / softness), 0.0, 1.0);
435									hit_light2.rgb *= hit_light2.a;
436								}
437		
438								float prev_radius = i == 0 ? 0.0 : radius_sizes[max(0, i - 1)];
439								float blend = clamp((length(ray_pos) - prev_radius) / (radius_sizes[i] - prev_radius), 0.0, 1.0);
440		
441								fdistance2 /= sdfgi.cascades[next_i].to_cell;
442		
443								hit_light = mix(hit_light, hit_light2, blend);
444								fdistance = mix(fdistance, fdistance2, blend);
445							}
446		
447							light_accum += hit_light;
448							ray_pos += ray_dir * fdistance;
449							found = true;
450						}
451						i++;
452						if (i == sdfgi.max_cascades) {
453							i = 0;
454							found = false;
455						}
456					}
457		
458					vec3 light = light_accum.rgb / max(light_accum.a, 0.00001);
459					float alpha = min(1.0, light_accum.a);
460		
461					float b = min(1.0, roughness * 5.0);
462		
463					float sa = 1.0 - b;
464		
465					reflection_light.a = alpha * sa + b;
466					if (reflection_light.a == 0) {
467						specular = vec3(0.0);
468					} else {
469						specular = (light * alpha * sa + specular * b) / reflection_light.a;
470					}
471				}
472		
473				reflection_light.rgb = specular;
474		
475				ambient_light.rgb *= sdfgi.energy;
476				reflection_light.rgb *= sdfgi.energy;
477			} else {
478				ambient_light = vec4(0);
479				reflection_light = vec4(0);
480			}
481		}
482		
483		//standard voxel cone trace
484		vec4 voxel_cone_trace(texture3D probe, vec3 cell_size, vec3 pos, vec3 direction, float tan_half_angle, float max_distance, float p_bias) {
485			float dist = p_bias;
486			vec4 color = vec4(0.0);
487		
488			while (dist < max_distance && color.a < 0.95) {
489				float diameter = max(1.0, 2.0 * tan_half_angle * dist);
490				vec3 uvw_pos = (pos + dist * direction) * cell_size;
491				float half_diameter = diameter * 0.5;
492				//check if outside, then break
493				if (any(greaterThan(abs(uvw_pos - 0.5), vec3(0.5f + half_diameter * cell_size)))) {
494					break;
495				}
496				vec4 scolor = textureLod(sampler3D(probe, linear_sampler_with_mipmaps), uvw_pos, log2(diameter));
497				float a = (1.0 - color.a);
498				color += a * scolor;
499				dist += half_diameter;
500			}
501		
502			return color;
503		}
504		
505		vec4 voxel_cone_trace_45_degrees(texture3D probe, vec3 cell_size, vec3 pos, vec3 direction, float max_distance, float p_bias) {
506			float dist = p_bias;
507			vec4 color = vec4(0.0);
508			float radius = max(0.5, dist);
509			float lod_level = log2(radius * 2.0);
510		
511			while (dist < max_distance && color.a < 0.95) {
512				vec3 uvw_pos = (pos + dist * direction) * cell_size;
513		
514				//check if outside, then break
515				if (any(greaterThan(abs(uvw_pos - 0.5), vec3(0.5f + radius * cell_size)))) {
516					break;
517				}
518				vec4 scolor = textureLod(sampler3D(probe, linear_sampler_with_mipmaps), uvw_pos, lod_level);
519				lod_level += 1.0;
520		
521				float a = (1.0 - color.a);
522				scolor *= a;
523				color += scolor;
524				dist += radius;
525				radius = max(0.5, dist);
526			}
527			return color;
528		}
529		
530		void voxel_gi_compute(uint index, vec3 position, vec3 normal, vec3 ref_vec, mat3 normal_xform, float roughness, inout vec4 out_spec, inout vec4 out_diff, inout float out_blend) {
531			position = (voxel_gi_instances.data[index].xform * vec4(position, 1.0)).xyz;
532			ref_vec = normalize((voxel_gi_instances.data[index].xform * vec4(ref_vec, 0.0)).xyz);
533			normal = normalize((voxel_gi_instances.data[index].xform * vec4(normal, 0.0)).xyz);
534		
535			position += normal * voxel_gi_instances.data[index].normal_bias;
536		
537			//this causes corrupted pixels, i have no idea why..
538			if (any(bvec2(any(lessThan(position, vec3(0.0))), any(greaterThan(position, voxel_gi_instances.data[index].bounds))))) {
539				return;
540			}
541		
542			mat3 dir_xform = mat3(voxel_gi_instances.data[index].xform) * normal_xform;
543		
544			vec3 blendv = abs(position / voxel_gi_instances.data[index].bounds * 2.0 - 1.0);
545			float blend = clamp(1.0 - max(blendv.x, max(blendv.y, blendv.z)), 0.0, 1.0);
546			//float blend=1.0;
547		
548			float max_distance = length(voxel_gi_instances.data[index].bounds);
549			vec3 cell_size = 1.0 / voxel_gi_instances.data[index].bounds;
550		
551			//irradiance
552		
553			vec4 light = vec4(0.0);
554		
555			if (params.high_quality_vct) {
556				const uint cone_dir_count = 6;
557				vec3 cone_dirs[cone_dir_count] = vec3[](
558						vec3(0.0, 0.0, 1.0),
559						vec3(0.866025, 0.0, 0.5),
560						vec3(0.267617, 0.823639, 0.5),
561						vec3(-0.700629, 0.509037, 0.5),
562						vec3(-0.700629, -0.509037, 0.5),
563						vec3(0.267617, -0.823639, 0.5));
564		
565				float cone_weights[cone_dir_count] = float[](0.25, 0.15, 0.15, 0.15, 0.15, 0.15);
566				float cone_angle_tan = 0.577;
567		
568				for (uint i = 0; i < cone_dir_count; i++) {
569					vec3 dir = normalize(dir_xform * cone_dirs[i]);
570					light += cone_weights[i] * voxel_cone_trace(voxel_gi_textures[index], cell_size, position, dir, cone_angle_tan, max_distance, voxel_gi_instances.data[index].bias);
571				}
572			} else {
573				const uint cone_dir_count = 4;
574				vec3 cone_dirs[cone_dir_count] = vec3[](
575						vec3(0.707107, 0.0, 0.707107),
576						vec3(0.0, 0.707107, 0.707107),
577						vec3(-0.707107, 0.0, 0.707107),
578						vec3(0.0, -0.707107, 0.707107));
579		
580				float cone_weights[cone_dir_count] = float[](0.25, 0.25, 0.25, 0.25);
581				for (int i = 0; i < cone_dir_count; i++) {
582					vec3 dir = normalize(dir_xform * cone_dirs[i]);
583					light += cone_weights[i] * voxel_cone_trace_45_degrees(voxel_gi_textures[index], cell_size, position, dir, max_distance, voxel_gi_instances.data[index].bias);
584				}
585			}
586		
587			light.rgb *= voxel_gi_instances.data[index].dynamic_range * voxel_gi_instances.data[index].exposure_normalization;
588			if (!voxel_gi_instances.data[index].blend_ambient) {
589				light.a = 1.0;
590			}
591		
592			out_diff += light * blend;
593		
594			//radiance
595			vec4 irr_light = voxel_cone_trace(voxel_gi_textures[index], cell_size, position, ref_vec, tan(roughness * 0.5 * M_PI * 0.99), max_distance, voxel_gi_instances.data[index].bias);
596			irr_light.rgb *= voxel_gi_instances.data[index].dynamic_range * voxel_gi_instances.data[index].exposure_normalization;
597			if (!voxel_gi_instances.data[index].blend_ambient) {
598				irr_light.a = 1.0;
599			}
600		
601			out_spec += irr_light * blend;
602		
603			out_blend += blend;
604		}
605		
606		vec4 fetch_normal_and_roughness(ivec2 pos) {
607			vec4 normal_roughness = texelFetch(sampler2D(normal_roughness_buffer, linear_sampler), pos, 0);
608			normal_roughness.xyz = normalize(normal_roughness.xyz * 2.0 - 1.0);
609			return normal_roughness;
610		}
611		
612		void process_gi(ivec2 pos, vec3 vertex, inout vec4 ambient_light, inout vec4 reflection_light) {
613			vec4 normal_roughness = fetch_normal_and_roughness(pos);
614		
615			vec3 normal = normal_roughness.xyz;
616		
617			if (normal.length() > 0.5) {
618				//valid normal, can do GI
619				float roughness = normal_roughness.w;
620				vec3 view = -normalize(mat3(scene_data.cam_transform) * (vertex - scene_data.eye_offset[gl_GlobalInvocationID.z].xyz));
621				vertex = mat3(scene_data.cam_transform) * vertex;
622				normal = normalize(mat3(scene_data.cam_transform) * normal);
623				vec3 reflection = normalize(reflect(-view, normal));
624		
625		#ifdef USE_SDFGI
626				sdfgi_process(vertex, normal, reflection, roughness, ambient_light, reflection_light);
627		#endif
628		
629		#ifdef USE_VOXEL_GI_INSTANCES
630				{
631		#ifdef SAMPLE_VOXEL_GI_NEAREST
632					uvec2 voxel_gi_tex = texelFetch(voxel_gi_buffer, pos, 0).rg;
633		#else
634					uvec2 voxel_gi_tex = texelFetch(usampler2D(voxel_gi_buffer, linear_sampler), pos, 0).rg;
635		#endif
636					roughness *= roughness;
637					//find arbitrary tangent and bitangent, then build a matrix
638					vec3 v0 = abs(normal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
639					vec3 tangent = normalize(cross(v0, normal));
640					vec3 bitangent = normalize(cross(tangent, normal));
641					mat3 normal_mat = mat3(tangent, bitangent, normal);
642		
643					vec4 amb_accum = vec4(0.0);
644					vec4 spec_accum = vec4(0.0);
645					float blend_accum = 0.0;
646		
647					for (uint i = 0; i < params.max_voxel_gi_instances; i++) {
648						if (any(equal(uvec2(i), voxel_gi_tex))) {
649							voxel_gi_compute(i, vertex, normal, reflection, normal_mat, roughness, spec_accum, amb_accum, blend_accum);
650						}
651					}
652					if (blend_accum > 0.0) {
653						amb_accum /= blend_accum;
654						spec_accum /= blend_accum;
655					}
656		
657		#ifdef USE_SDFGI
658					reflection_light = blend_color(spec_accum, reflection_light);
659					ambient_light = blend_color(amb_accum, ambient_light);
660		#else
661					reflection_light = spec_accum;
662					ambient_light = amb_accum;
663		#endif
664				}
665		#endif
666			}
667		}
668		
669		void main() {
670			ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
671		
672			uint vrs_x, vrs_y;
673		#ifdef USE_VRS
674			if (sc_use_vrs) {
675				ivec2 vrs_pos;
676		
677				// Currently we use a 16x16 texel, possibly some day make this configurable.
678				if (sc_half_res) {
679					vrs_pos = pos >> 3;
680				} else {
681					vrs_pos = pos >> 4;
682				}
683		
684				uint vrs_texel = imageLoad(vrs_buffer, vrs_pos).r;
685				// note, valid values for vrs_x and vrs_y are 1, 2 and 4.
686				vrs_x = 1 << ((vrs_texel >> 2) & 3);
687				vrs_y = 1 << (vrs_texel & 3);
688		
689				if (mod(pos.x, vrs_x) != 0) {
690					return;
691				}
692		
693				if (mod(pos.y, vrs_y) != 0) {
694					return;
695				}
696			}
697		#endif
698		
699			if (sc_half_res) {
700				pos <<= 1;
701			}
702		
703			if (any(greaterThanEqual(pos, scene_data.screen_size))) { //too large, do nothing
704				return;
705			}
706		
707			vec4 ambient_light = vec4(0.0);
708			vec4 reflection_light = vec4(0.0);
709		
710			vec3 vertex = reconstruct_position(pos);
711			vertex.y = -vertex.y;
712		
713			process_gi(pos, vertex, ambient_light, reflection_light);
714		
715			if (sc_half_res) {
716				pos >>= 1;
717			}
718		
719			imageStore(ambient_buffer, pos, ambient_light);
720			imageStore(reflection_buffer, pos, reflection_light);
721		
722		#ifdef USE_VRS
723			if (sc_use_vrs) {
724				if (vrs_x > 1) {
725					imageStore(ambient_buffer, pos + ivec2(1, 0), ambient_light);
726					imageStore(reflection_buffer, pos + ivec2(1, 0), reflection_light);
727				}
728		
729				if (vrs_x > 2) {
730					imageStore(ambient_buffer, pos + ivec2(2, 0), ambient_light);
731					imageStore(reflection_buffer, pos + ivec2(2, 0), reflection_light);
732		
733					imageStore(ambient_buffer, pos + ivec2(3, 0), ambient_light);
734					imageStore(reflection_buffer, pos + ivec2(3, 0), reflection_light);
735				}
736		
737				if (vrs_y > 1) {
738					imageStore(ambient_buffer, pos + ivec2(0, 1), ambient_light);
739					imageStore(reflection_buffer, pos + ivec2(0, 1), reflection_light);
740				}
741		
742				if (vrs_y > 1 && vrs_x > 1) {
743					imageStore(ambient_buffer, pos + ivec2(1, 1), ambient_light);
744					imageStore(reflection_buffer, pos + ivec2(1, 1), reflection_light);
745				}
746		
747				if (vrs_y > 1 && vrs_x > 2) {
748					imageStore(ambient_buffer, pos + ivec2(2, 1), ambient_light);
749					imageStore(reflection_buffer, pos + ivec2(2, 1), reflection_light);
750		
751					imageStore(ambient_buffer, pos + ivec2(3, 1), ambient_light);
752					imageStore(reflection_buffer, pos + ivec2(3, 1), reflection_light);
753				}
754		
755				if (vrs_y > 2) {
756					imageStore(ambient_buffer, pos + ivec2(0, 2), ambient_light);
757					imageStore(reflection_buffer, pos + ivec2(0, 2), reflection_light);
758					imageStore(ambient_buffer, pos + ivec2(0, 3), ambient_light);
759					imageStore(reflection_buffer, pos + ivec2(0, 3), reflection_light);
760				}
761		
762				if (vrs_y > 2 && vrs_x > 1) {
763					imageStore(ambient_buffer, pos + ivec2(1, 2), ambient_light);
764					imageStore(reflection_buffer, pos + ivec2(1, 2), reflection_light);
765					imageStore(ambient_buffer, pos + ivec2(1, 3), ambient_light);
766					imageStore(reflection_buffer, pos + ivec2(1, 3), reflection_light);
767				}
768		
769				if (vrs_y > 2 && vrs_x > 2) {
770					imageStore(ambient_buffer, pos + ivec2(2, 2), ambient_light);
771					imageStore(reflection_buffer, pos + ivec2(2, 2), reflection_light);
772					imageStore(ambient_buffer, pos + ivec2(2, 3), ambient_light);
773					imageStore(reflection_buffer, pos + ivec2(2, 3), reflection_light);
774		
775					imageStore(ambient_buffer, pos + ivec2(3, 2), ambient_light);
776					imageStore(reflection_buffer, pos + ivec2(3, 2), reflection_light);
777					imageStore(ambient_buffer, pos + ivec2(3, 3), ambient_light);
778					imageStore(reflection_buffer, pos + ivec2(3, 3), reflection_light);
779				}
780			}
781		#endif
782		}
783		
784		
          RDShaderFile                                    RSRC