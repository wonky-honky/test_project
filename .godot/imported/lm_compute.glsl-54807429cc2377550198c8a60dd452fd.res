RSRC                    RDShaderFile            ’’’’’’’’                                                  resource_local_to_scene    resource_name    bytecode_vertex    bytecode_fragment    bytecode_tesselation_control     bytecode_tesselation_evaluation    bytecode_compute    compile_error_vertex    compile_error_fragment "   compile_error_tesselation_control %   compile_error_tesselation_evaluation    compile_error_compute    script 
   _versions    base_error           local://RDShaderSPIRV_b37p0          local://RDShaderSPIRV_hj370 Å°         local://RDShaderSPIRV_3or8o ^        local://RDShaderSPIRV_q3as0 M        local://RDShaderSPIRV_b1gdf ŗ        local://RDShaderSPIRV_srcx3 Ūg        local://RDShaderFile_5c76c         RDShaderSPIRV          ­  Failed parse:
ERROR: 0:282: 'CLUSTER_SIZE' : undeclared identifier 
ERROR: 0:282: '' : compilation terminated 
ERROR: 2 compilation errors.  No code generated.




Stage 'compute' source code: 

1		
2		#version 450
3		
4		#
5		#define MODE_DENOISE
6		
7		
8		
9		// One 2D local group focusing in one layer at a time, though all
10		// in parallel (no barriers) makes more sense than a 3D local group
11		// as this can take more advantage of the cache for each group.
12		
13		#ifdef MODE_LIGHT_PROBES
14		
15		layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
16		
17		#else
18		
19		layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
20		
21		#endif
22		
23		
24		
25		/* SET 0, static data that does not change between any call */
26		
27		layout(set = 0, binding = 0) uniform BakeParameters {
28			vec3 world_size;
29			float bias;
30		
31			vec3 to_cell_offset;
32			int grid_size;
33		
34			vec3 to_cell_size;
35			uint light_count;
36		
37			mat3x4 env_transform;
38		
39			ivec2 atlas_size;
40			float exposure_normalization;
41			uint bounces;
42		
43			float bounce_indirect_energy;
44		}
45		bake_params;
46		
47		struct Vertex {
48			vec3 position;
49			float normal_z;
50			vec2 uv;
51			vec2 normal_xy;
52		};
53		
54		layout(set = 0, binding = 1, std430) restrict readonly buffer Vertices {
55			Vertex data[];
56		}
57		vertices;
58		
59		struct Triangle {
60			uvec3 indices;
61			uint slice;
62			vec3 min_bounds;
63			uint pad0;
64			vec3 max_bounds;
65			uint pad1;
66		};
67		
68		struct ClusterAABB {
69			vec3 min_bounds;
70			uint pad0;
71			vec3 max_bounds;
72			uint pad1;
73		};
74		
75		layout(set = 0, binding = 2, std430) restrict readonly buffer Triangles {
76			Triangle data[];
77		}
78		triangles;
79		
80		layout(set = 0, binding = 3, std430) restrict readonly buffer TriangleIndices {
81			uint data[];
82		}
83		triangle_indices;
84		
85		#define LIGHT_TYPE_DIRECTIONAL 0
86		#define LIGHT_TYPE_OMNI 1
87		#define LIGHT_TYPE_SPOT 2
88		
89		struct Light {
90			vec3 position;
91			uint type;
92		
93			vec3 direction;
94			float energy;
95		
96			vec3 color;
97			float size;
98		
99			float range;
100			float attenuation;
101			float cos_spot_angle;
102			float inv_spot_attenuation;
103		
104			float indirect_energy;
105			float shadow_blur;
106			bool static_bake;
107			uint pad;
108		};
109		
110		layout(set = 0, binding = 4, std430) restrict readonly buffer Lights {
111			Light data[];
112		}
113		lights;
114		
115		struct Seam {
116			uvec2 a;
117			uvec2 b;
118		};
119		
120		layout(set = 0, binding = 5, std430) restrict readonly buffer Seams {
121			Seam data[];
122		}
123		seams;
124		
125		layout(set = 0, binding = 6, std430) restrict readonly buffer Probes {
126			vec4 data[];
127		}
128		probe_positions;
129		
130		layout(set = 0, binding = 7) uniform utexture3D grid;
131		
132		layout(set = 0, binding = 8) uniform texture2DArray albedo_tex;
133		layout(set = 0, binding = 9) uniform texture2DArray emission_tex;
134		
135		layout(set = 0, binding = 10) uniform sampler linear_sampler;
136		
137		layout(set = 0, binding = 11, std430) restrict readonly buffer ClusterIndices {
138			uint data[];
139		}
140		cluster_indices;
141		
142		layout(set = 0, binding = 12, std430) restrict readonly buffer ClusterAABBs {
143			ClusterAABB data[];
144		}
145		cluster_aabbs;
146		
147		// Fragment action constants
148		const uint FA_NONE = 0;
149		const uint FA_SMOOTHEN_POSITION = 1;
150		
151		
152		#ifdef MODE_LIGHT_PROBES
153		
154		layout(set = 1, binding = 0, std430) restrict buffer LightProbeData {
155			vec4 data[];
156		}
157		light_probes;
158		
159		layout(set = 1, binding = 1) uniform texture2DArray source_light;
160		layout(set = 1, binding = 2) uniform texture2D environment;
161		#endif
162		
163		#ifdef MODE_UNOCCLUDE
164		
165		layout(rgba32f, set = 1, binding = 0) uniform restrict image2DArray position;
166		layout(rgba32f, set = 1, binding = 1) uniform restrict readonly image2DArray unocclude;
167		
168		#endif
169		
170		#if defined(MODE_DIRECT_LIGHT) || defined(MODE_BOUNCE_LIGHT)
171		
172		layout(rgba16f, set = 1, binding = 0) uniform restrict writeonly image2DArray dest_light;
173		layout(set = 1, binding = 1) uniform texture2DArray source_light;
174		layout(set = 1, binding = 2) uniform texture2DArray source_position;
175		layout(set = 1, binding = 3) uniform texture2DArray source_normal;
176		layout(rgba16f, set = 1, binding = 4) uniform restrict image2DArray accum_light;
177		
178		#endif
179		
180		#ifdef MODE_BOUNCE_LIGHT
181		layout(set = 1, binding = 5) uniform texture2D environment;
182		#endif
183		
184		#if defined(MODE_DILATE) || defined(MODE_DENOISE)
185		layout(rgba16f, set = 1, binding = 0) uniform restrict writeonly image2DArray dest_light;
186		layout(set = 1, binding = 1) uniform texture2DArray source_light;
187		#endif
188		
189		#ifdef MODE_DENOISE
190		layout(set = 1, binding = 2) uniform texture2DArray source_normal;
191		layout(set = 1, binding = 3) uniform DenoiseParams {
192			float spatial_bandwidth;
193			float light_bandwidth;
194			float albedo_bandwidth;
195			float normal_bandwidth;
196		
197			float filter_strength;
198		}
199		denoise_params;
200		#endif
201		
202		layout(push_constant, std430) uniform Params {
203			uint atlas_slice;
204			uint ray_count;
205			uint ray_from;
206			uint ray_to;
207		
208			ivec2 region_ofs;
209			uint probe_count;
210		}
211		params;
212		
213		//check it, but also return distance and barycentric coords (for uv lookup)
214		bool ray_hits_triangle(vec3 from, vec3 dir, float max_dist, vec3 p0, vec3 p1, vec3 p2, out float r_distance, out vec3 r_barycentric) {
215			const float EPSILON = 0.00001;
216			const vec3 e0 = p1 - p0;
217			const vec3 e1 = p0 - p2;
218			vec3 triangle_normal = cross(e1, e0);
219		
220			float n_dot_dir = dot(triangle_normal, dir);
221		
222			if (abs(n_dot_dir) < EPSILON) {
223				return false;
224			}
225		
226			const vec3 e2 = (p0 - from) / n_dot_dir;
227			const vec3 i = cross(dir, e2);
228		
229			r_barycentric.y = dot(i, e1);
230			r_barycentric.z = dot(i, e0);
231			r_barycentric.x = 1.0 - (r_barycentric.z + r_barycentric.y);
232			r_distance = dot(triangle_normal, e2);
233		
234			return (r_distance > bake_params.bias) && (r_distance < max_dist) && all(greaterThanEqual(r_barycentric, vec3(0.0)));
235		}
236		
237		const uint RAY_MISS = 0;
238		const uint RAY_FRONT = 1;
239		const uint RAY_BACK = 2;
240		const uint RAY_ANY = 3;
241		
242		bool ray_box_test(vec3 p_from, vec3 p_inv_dir, vec3 p_box_min, vec3 p_box_max) {
243			vec3 t0 = (p_box_min - p_from) * p_inv_dir;
244			vec3 t1 = (p_box_max - p_from) * p_inv_dir;
245			vec3 tmin = min(t0, t1), tmax = max(t0, t1);
246			return max(tmin.x, max(tmin.y, tmin.z)) <= min(tmax.x, min(tmax.y, tmax.z));
247		}
248		
249		#if CLUSTER_SIZE > 32
250		#define CLUSTER_TRIANGLE_ITERATION
251		#endif
252		
253		uint trace_ray(vec3 p_from, vec3 p_to, bool p_any_hit, out float r_distance, out vec3 r_normal, out uint r_triangle, out vec3 r_barycentric) {
254			// World coordinates.
255			vec3 rel = p_to - p_from;
256			float rel_len = length(rel);
257			vec3 dir = normalize(rel);
258			vec3 inv_dir = 1.0 / dir;
259		
260			// Cell coordinates.
261			vec3 from_cell = (p_from - bake_params.to_cell_offset) * bake_params.to_cell_size;
262			vec3 to_cell = (p_to - bake_params.to_cell_offset) * bake_params.to_cell_size;
263		
264			// Prepare DDA.
265			vec3 rel_cell = to_cell - from_cell;
266			ivec3 icell = ivec3(from_cell);
267			ivec3 iendcell = ivec3(to_cell);
268			vec3 dir_cell = normalize(rel_cell);
269			vec3 delta = min(abs(1.0 / dir_cell), bake_params.grid_size); // Use bake_params.grid_size as max to prevent infinity values.
270			ivec3 step = ivec3(sign(rel_cell));
271			vec3 side = (sign(rel_cell) * (vec3(icell) - from_cell) + (sign(rel_cell) * 0.5) + 0.5) * delta;
272		
273			uint iters = 0;
274			while (all(greaterThanEqual(icell, ivec3(0))) && all(lessThan(icell, ivec3(bake_params.grid_size))) && (iters < 1000)) {
275				uvec2 cell_data = texelFetch(usampler3D(grid, linear_sampler), icell, 0).xy;
276				uint triangle_count = cell_data.x;
277				if (triangle_count > 0) {
278					uint hit = RAY_MISS;
279					float best_distance = 1e20;
280					uint cluster_start = cluster_indices.data[cell_data.y * 2];
281					uint cell_triangle_start = cluster_indices.data[cell_data.y * 2 + 1];
282					uint cluster_count = (triangle_count + CLUSTER_SIZE - 1) / CLUSTER_SIZE;
283					uint cluster_base_index = 0;
284					while (cluster_base_index < cluster_count) {
285						// To minimize divergence, all Ray-AABB tests on the clusters contained in the cell are performed
286						// before checking against the triangles. We do this 32 clusters at a time and store the intersected
287						// clusters on each bit of the 32-bit integer.
288						uint cluster_test_count = min(32, cluster_count - cluster_base_index);
289						uint cluster_hits = 0;
290						for (uint i = 0; i < cluster_test_count; i++) {
291							uint cluster_index = cluster_start + cluster_base_index + i;
292							ClusterAABB cluster_aabb = cluster_aabbs.data[cluster_index];
293							if (ray_box_test(p_from, inv_dir, cluster_aabb.min_bounds, cluster_aabb.max_bounds)) {
294								cluster_hits |= (1 << i);
295							}
296						}
297		
298						// Check the triangles in any of the clusters that were intersected by toggling off the bits in the
299						// 32-bit integer counter until no bits are left.
300						while (cluster_hits > 0) {
301							uint cluster_index = findLSB(cluster_hits);
302							cluster_hits &= ~(1 << cluster_index);
303							cluster_index += cluster_base_index;
304		
305							// Do the same divergence execution trick with triangles as well.
306							uint triangle_base_index = 0;
307		#ifdef CLUSTER_TRIANGLE_ITERATION
308							while (triangle_base_index < triangle_count)
309		#endif
310							{
311								uint triangle_start_index = cell_triangle_start + cluster_index * CLUSTER_SIZE + triangle_base_index;
312								uint triangle_test_count = min(CLUSTER_SIZE, triangle_count - triangle_base_index);
313								uint triangle_hits = 0;
314								for (uint i = 0; i < triangle_test_count; i++) {
315									uint triangle_index = triangle_indices.data[triangle_start_index + i];
316									if (ray_box_test(p_from, inv_dir, triangles.data[triangle_index].min_bounds, triangles.data[triangle_index].max_bounds)) {
317										triangle_hits |= (1 << i);
318									}
319								}
320		
321								while (triangle_hits > 0) {
322									uint cluster_triangle_index = findLSB(triangle_hits);
323									triangle_hits &= ~(1 << cluster_triangle_index);
324									cluster_triangle_index += triangle_start_index;
325		
326									uint triangle_index = triangle_indices.data[cluster_triangle_index];
327									Triangle triangle = triangles.data[triangle_index];
328		
329									// Gather the triangle vertex positions.
330									vec3 vtx0 = vertices.data[triangle.indices.x].position;
331									vec3 vtx1 = vertices.data[triangle.indices.y].position;
332									vec3 vtx2 = vertices.data[triangle.indices.z].position;
333									vec3 normal = -normalize(cross((vtx0 - vtx1), (vtx0 - vtx2)));
334									bool backface = dot(normal, dir) >= 0.0;
335									float distance;
336									vec3 barycentric;
337									if (ray_hits_triangle(p_from, dir, rel_len, vtx0, vtx1, vtx2, distance, barycentric)) {
338										if (p_any_hit) {
339											// Return early if any hit was requested.
340											return RAY_ANY;
341										}
342		
343										vec3 position = p_from + dir * distance;
344										vec3 hit_cell = (position - bake_params.to_cell_offset) * bake_params.to_cell_size;
345										if (icell != ivec3(hit_cell)) {
346											// It's possible for the ray to hit a triangle in a position outside the bounds of the cell
347											// if it's large enough to cover multiple ones. The hit must be ignored if this is the case.
348											continue;
349										}
350		
351										if (!backface) {
352											// The case of meshes having both a front and back face in the same plane is more common than
353											// expected, so if this is a front-face, bias it closer to the ray origin, so it always wins
354											// over the back-face.
355											distance = max(bake_params.bias, distance - bake_params.bias);
356										}
357		
358										if (distance < best_distance) {
359											hit = backface ? RAY_BACK : RAY_FRONT;
360											best_distance = distance;
361											r_distance = distance;
362											r_normal = normal;
363											r_triangle = triangle_index;
364											r_barycentric = barycentric;
365										}
366									}
367								}
368		
369		#ifdef CLUSTER_TRIANGLE_ITERATION
370								triangle_base_index += CLUSTER_SIZE;
371		#endif
372							}
373						}
374		
375						cluster_base_index += 32;
376					}
377		
378					if (hit != RAY_MISS) {
379						return hit;
380					}
381				}
382		
383				if (icell == iendcell) {
384					break;
385				}
386		
387				bvec3 mask = lessThanEqual(side.xyz, min(side.yzx, side.zxy));
388				side += vec3(mask) * delta;
389				icell += ivec3(vec3(mask)) * step;
390				iters++;
391			}
392		
393			return RAY_MISS;
394		}
395		
396		uint trace_ray_closest_hit_triangle(vec3 p_from, vec3 p_to, out uint r_triangle, out vec3 r_barycentric) {
397			float distance;
398			vec3 normal;
399			return trace_ray(p_from, p_to, false, distance, normal, r_triangle, r_barycentric);
400		}
401		
402		uint trace_ray_closest_hit_distance(vec3 p_from, vec3 p_to, out float r_distance, out vec3 r_normal) {
403			uint triangle;
404			vec3 barycentric;
405			return trace_ray(p_from, p_to, false, r_distance, r_normal, triangle, barycentric);
406		}
407		
408		uint trace_ray_any_hit(vec3 p_from, vec3 p_to) {
409			float distance;
410			vec3 normal;
411			uint triangle;
412			vec3 barycentric;
413			return trace_ray(p_from, p_to, true, distance, normal, triangle, barycentric);
414		}
415		
416		// https://www.reedbeta.com/blog/hash-functions-for-gpu-rendering/
417		uint hash(uint value) {
418			uint state = value * 747796405u + 2891336453u;
419			uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
420			return (word >> 22u) ^ word;
421		}
422		
423		uint random_seed(ivec3 seed) {
424			return hash(seed.x ^ hash(seed.y ^ hash(seed.z)));
425		}
426		
427		// generates a random value in range [0.0, 1.0)
428		float randomize(inout uint value) {
429			value = hash(value);
430			return float(value / 4294967296.0);
431		}
432		
433		const float PI = 3.14159265f;
434		
435		// http://www.realtimerendering.com/raytracinggems/unofficial_RayTracingGems_v1.4.pdf (chapter 15)
436		vec3 generate_hemisphere_cosine_weighted_direction(inout uint noise) {
437			float noise1 = randomize(noise);
438			float noise2 = randomize(noise) * 2.0 * PI;
439		
440			return vec3(sqrt(noise1) * cos(noise2), sqrt(noise1) * sin(noise2), sqrt(1.0 - noise1));
441		}
442		
443		// Distribution generation adapted from "Generating uniformly distributed numbers on a sphere"
444		// <http://corysimon.github.io/articles/uniformdistn-on-sphere/>
445		vec3 generate_sphere_uniform_direction(inout uint noise) {
446			float theta = 2.0 * PI * randomize(noise);
447			float phi = acos(1.0 - 2.0 * randomize(noise));
448			return vec3(sin(phi) * cos(theta), sin(phi) * sin(theta), cos(phi));
449		}
450		
451		vec3 generate_ray_dir_from_normal(vec3 normal, inout uint noise) {
452			vec3 v0 = abs(normal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
453			vec3 tangent = normalize(cross(v0, normal));
454			vec3 bitangent = normalize(cross(tangent, normal));
455			mat3 normal_mat = mat3(tangent, bitangent, normal);
456			return normal_mat * generate_hemisphere_cosine_weighted_direction(noise);
457		}
458		
459		#if defined(MODE_DIRECT_LIGHT) || defined(MODE_BOUNCE_LIGHT) || defined(MODE_LIGHT_PROBES)
460		
461		float get_omni_attenuation(float distance, float inv_range, float decay) {
462			float nd = distance * inv_range;
463			nd *= nd;
464			nd *= nd; // nd^4
465			nd = max(1.0 - nd, 0.0);
466			nd *= nd; // nd^2
467			return nd * pow(max(distance, 0.0001), -decay);
468		}
469		
470		void trace_direct_light(vec3 p_position, vec3 p_normal, uint p_light_index, bool p_soft_shadowing, out vec3 r_light, out vec3 r_light_dir, inout uint r_noise) {
471			r_light = vec3(0.0f);
472		
473			vec3 light_pos;
474			float dist;
475			float attenuation;
476			float soft_shadowing_disk_size;
477			Light light_data = lights.data[p_light_index];
478			if (light_data.type == LIGHT_TYPE_DIRECTIONAL) {
479				vec3 light_vec = light_data.direction;
480				light_pos = p_position - light_vec * length(bake_params.world_size);
481				r_light_dir = normalize(light_pos - p_position);
482				dist = length(bake_params.world_size);
483				attenuation = 1.0;
484				soft_shadowing_disk_size = light_data.size;
485			} else {
486				light_pos = light_data.position;
487				r_light_dir = normalize(light_pos - p_position);
488				dist = distance(p_position, light_pos);
489				if (dist > light_data.range) {
490					return;
491				}
492		
493				soft_shadowing_disk_size = light_data.size / dist;
494		
495				attenuation = get_omni_attenuation(dist, 1.0 / light_data.range, light_data.attenuation);
496		
497				if (light_data.type == LIGHT_TYPE_SPOT) {
498					vec3 rel = normalize(p_position - light_pos);
499					float cos_spot_angle = light_data.cos_spot_angle;
500					float cos_angle = dot(rel, light_data.direction);
501		
502					if (cos_angle < cos_spot_angle) {
503						return;
504					}
505		
506					float scos = max(cos_angle, cos_spot_angle);
507					float spot_rim = max(0.0001, (1.0 - scos) / (1.0 - cos_spot_angle));
508					attenuation *= 1.0 - pow(spot_rim, light_data.inv_spot_attenuation);
509				}
510			}
511		
512			attenuation *= max(0.0, dot(p_normal, r_light_dir));
513			if (attenuation <= 0.0001) {
514				return;
515			}
516		
517			float penumbra = 0.0;
518			if ((light_data.size > 0.0) && p_soft_shadowing) {
519				vec3 light_to_point = -r_light_dir;
520				vec3 aux = light_to_point.y < 0.777 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
521				vec3 light_to_point_tan = normalize(cross(light_to_point, aux));
522				vec3 light_to_point_bitan = normalize(cross(light_to_point, light_to_point_tan));
523		
524				const uint shadowing_rays_check_penumbra_denom = 2;
525				uint shadowing_ray_count = p_soft_shadowing ? params.ray_count : 1;
526		
527				uint hits = 0;
528				vec3 light_disk_to_point = light_to_point;
529				for (uint j = 0; j < shadowing_ray_count; j++) {
530					// Optimization:
531					// Once already traced an important proportion of rays, if all are hits or misses,
532					// assume we're not in the penumbra so we can infer the rest would have the same result
533					if (p_soft_shadowing) {
534						if (j == shadowing_ray_count / shadowing_rays_check_penumbra_denom) {
535							if (hits == j) {
536								// Assume totally lit
537								hits = shadowing_ray_count;
538								break;
539							} else if (hits == 0) {
540								// Assume totally dark
541								hits = 0;
542								break;
543							}
544						}
545					}
546		
547					float r = randomize(r_noise);
548					float a = randomize(r_noise) * 2.0 * PI;
549					vec2 disk_sample = (r * vec2(cos(a), sin(a))) * soft_shadowing_disk_size * light_data.shadow_blur;
550					light_disk_to_point = normalize(light_to_point + disk_sample.x * light_to_point_tan + disk_sample.y * light_to_point_bitan);
551		
552					if (trace_ray_any_hit(p_position - light_disk_to_point * bake_params.bias, p_position - light_disk_to_point * dist) == RAY_MISS) {
553						hits++;
554					}
555				}
556		
557				penumbra = float(hits) / float(shadowing_ray_count);
558			} else {
559				if (trace_ray_any_hit(p_position + r_light_dir * bake_params.bias, light_pos) == RAY_MISS) {
560					penumbra = 1.0;
561				}
562			}
563		
564			r_light = light_data.color * light_data.energy * attenuation * penumbra;
565		}
566		
567		#endif
568		
569		#if defined(MODE_BOUNCE_LIGHT) || defined(MODE_LIGHT_PROBES)
570		
571		vec3 trace_environment_color(vec3 ray_dir) {
572			vec3 sky_dir = normalize(mat3(bake_params.env_transform) * ray_dir);
573			vec2 st = vec2(atan(sky_dir.x, sky_dir.z), acos(sky_dir.y));
574			if (st.x < 0.0) {
575				st.x += PI * 2.0;
576			}
577		
578			return textureLod(sampler2D(environment, linear_sampler), st / vec2(PI * 2.0, PI), 0.0).rgb;
579		}
580		
581		vec3 trace_indirect_light(vec3 p_position, vec3 p_ray_dir, inout uint r_noise) {
582			// The lower limit considers the case where the lightmapper might have bounces disabled but light probes are requested.
583			vec3 position = p_position;
584			vec3 ray_dir = p_ray_dir;
585			uint max_depth = max(bake_params.bounces, 1);
586			vec3 throughput = vec3(1.0);
587			vec3 light = vec3(0.0);
588			for (uint depth = 0; depth < max_depth; depth++) {
589				uint tidx;
590				vec3 barycentric;
591				uint trace_result = trace_ray_closest_hit_triangle(position + ray_dir * bake_params.bias, position + ray_dir * length(bake_params.world_size), tidx, barycentric);
592				if (trace_result == RAY_FRONT) {
593					Vertex vert0 = vertices.data[triangles.data[tidx].indices.x];
594					Vertex vert1 = vertices.data[triangles.data[tidx].indices.y];
595					Vertex vert2 = vertices.data[triangles.data[tidx].indices.z];
596					vec3 uvw = vec3(barycentric.x * vert0.uv + barycentric.y * vert1.uv + barycentric.z * vert2.uv, float(triangles.data[tidx].slice));
597					position = barycentric.x * vert0.position + barycentric.y * vert1.position + barycentric.z * vert2.position;
598		
599					vec3 norm0 = vec3(vert0.normal_xy, vert0.normal_z);
600					vec3 norm1 = vec3(vert1.normal_xy, vert1.normal_z);
601					vec3 norm2 = vec3(vert2.normal_xy, vert2.normal_z);
602					vec3 normal = barycentric.x * norm0 + barycentric.y * norm1 + barycentric.z * norm2;
603		
604					vec3 direct_light = vec3(0.0f);
605		#ifdef USE_LIGHT_TEXTURE_FOR_BOUNCES
606					direct_light += textureLod(sampler2DArray(source_light, linear_sampler), uvw, 0.0).rgb;
607		#else
608					// Trace the lights directly. Significantly more expensive but more accurate in scenarios
609					// where the lightmap texture isn't reliable.
610					for (uint i = 0; i < bake_params.light_count; i++) {
611						vec3 light;
612						vec3 light_dir;
613						trace_direct_light(position, normal, i, false, light, light_dir, r_noise);
614						direct_light += light * lights.data[i].indirect_energy;
615					}
616		
617					direct_light *= bake_params.exposure_normalization;
618		#endif
619		
620					vec3 albedo = textureLod(sampler2DArray(albedo_tex, linear_sampler), uvw, 0).rgb;
621					vec3 emissive = textureLod(sampler2DArray(emission_tex, linear_sampler), uvw, 0).rgb;
622					emissive *= bake_params.exposure_normalization;
623		
624					light += throughput * emissive;
625					throughput *= albedo;
626					light += throughput * direct_light * bake_params.bounce_indirect_energy;
627		
628					// Use Russian Roulette to determine a probability to terminate the bounce earlier as an optimization.
629					// <https://computergraphics.stackexchange.com/questions/2316/is-russian-roulette-really-the-answer>
630					float p = max(max(throughput.x, throughput.y), throughput.z);
631					if (randomize(r_noise) > p) {
632						break;
633					}
634		
635					// Boost the throughput from the probability of the ray being terminated early.
636					throughput *= 1.0 / p;
637		
638					// Generate a new ray direction for the next bounce from this surface's normal.
639					ray_dir = generate_ray_dir_from_normal(normal, r_noise);
640				} else if (trace_result == RAY_MISS) {
641					// Look for the environment color and stop bouncing.
642					light += throughput * trace_environment_color(ray_dir);
643					break;
644				} else {
645					// Ignore any other trace results.
646					break;
647				}
648			}
649		
650			return light;
651		}
652		
653		#endif
654		
655		void main() {
656			// Check if invocation is out of bounds.
657		#ifdef MODE_LIGHT_PROBES
658			int probe_index = int(gl_GlobalInvocationID.x);
659			if (probe_index >= params.probe_count) {
660				return;
661			}
662		
663		#else
664			ivec2 atlas_pos = ivec2(gl_GlobalInvocationID.xy) + params.region_ofs;
665			if (any(greaterThanEqual(atlas_pos, bake_params.atlas_size))) {
666				return;
667			}
668		#endif
669		
670		#ifdef MODE_DIRECT_LIGHT
671		
672			vec3 normal = texelFetch(sampler2DArray(source_normal, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).xyz;
673			if (length(normal) < 0.5) {
674				return; //empty texel, no process
675			}
676			vec3 position = texelFetch(sampler2DArray(source_position, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).xyz;
677			vec3 light_for_texture = vec3(0.0);
678			vec3 light_for_bounces = vec3(0.0);
679		
680		#ifdef USE_SH_LIGHTMAPS
681			vec4 sh_accum[4] = vec4[](
682					vec4(0.0, 0.0, 0.0, 1.0),
683					vec4(0.0, 0.0, 0.0, 1.0),
684					vec4(0.0, 0.0, 0.0, 1.0),
685					vec4(0.0, 0.0, 0.0, 1.0));
686		#endif
687		
688			// Use atlas position and a prime number as the seed.
689			uint noise = random_seed(ivec3(atlas_pos, 43573547));
690			for (uint i = 0; i < bake_params.light_count; i++) {
691				vec3 light;
692				vec3 light_dir;
693				trace_direct_light(position, normal, i, true, light, light_dir, noise);
694		
695				if (lights.data[i].static_bake) {
696					light_for_texture += light;
697		
698		#ifdef USE_SH_LIGHTMAPS
699					float c[4] = float[](
700							0.282095, //l0
701							0.488603 * light_dir.y, //l1n1
702							0.488603 * light_dir.z, //l1n0
703							0.488603 * light_dir.x //l1p1
704					);
705		
706					for (uint j = 0; j < 4; j++) {
707						sh_accum[j].rgb += light * c[j] * 8.0;
708					}
709		#endif
710				}
711		
712				light_for_bounces += light * lights.data[i].indirect_energy;
713			}
714		
715			light_for_bounces *= bake_params.exposure_normalization;
716			imageStore(dest_light, ivec3(atlas_pos, params.atlas_slice), vec4(light_for_bounces, 1.0));
717		
718		#ifdef USE_SH_LIGHTMAPS
719			// Keep for adding at the end.
720			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + 0), sh_accum[0]);
721			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + 1), sh_accum[1]);
722			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + 2), sh_accum[2]);
723			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + 3), sh_accum[3]);
724		#else
725			light_for_texture *= bake_params.exposure_normalization;
726			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice), vec4(light_for_texture, 1.0));
727		#endif
728		
729		#endif
730		
731		#ifdef MODE_BOUNCE_LIGHT
732		
733		#ifdef USE_SH_LIGHTMAPS
734			vec4 sh_accum[4] = vec4[](
735					vec4(0.0, 0.0, 0.0, 1.0),
736					vec4(0.0, 0.0, 0.0, 1.0),
737					vec4(0.0, 0.0, 0.0, 1.0),
738					vec4(0.0, 0.0, 0.0, 1.0));
739		#else
740			vec3 light_accum = vec3(0.0);
741		#endif
742		
743			// Retrieve starting normal and position.
744			vec3 normal = texelFetch(sampler2DArray(source_normal, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).xyz;
745			if (length(normal) < 0.5) {
746				// The pixel is empty, skip processing it.
747				return;
748			}
749		
750			vec3 position = texelFetch(sampler2DArray(source_position, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).xyz;
751			uint noise = random_seed(ivec3(params.ray_from, atlas_pos));
752			for (uint i = params.ray_from; i < params.ray_to; i++) {
753				vec3 ray_dir = generate_ray_dir_from_normal(normal, noise);
754				vec3 light = trace_indirect_light(position, ray_dir, noise);
755		
756		#ifdef USE_SH_LIGHTMAPS
757				float c[4] = float[](
758						0.282095, //l0
759						0.488603 * ray_dir.y, //l1n1
760						0.488603 * ray_dir.z, //l1n0
761						0.488603 * ray_dir.x //l1p1
762				);
763		
764				for (uint j = 0; j < 4; j++) {
765					sh_accum[j].rgb += light * c[j] * 8.0;
766				}
767		#else
768				light_accum += light;
769		#endif
770			}
771		
772			// Add the averaged result to the accumulated light texture.
773		#ifdef USE_SH_LIGHTMAPS
774			for (int i = 0; i < 4; i++) {
775				vec4 accum = imageLoad(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + i));
776				accum.rgb += sh_accum[i].rgb / float(params.ray_count);
777				imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + i), accum);
778			}
779		#else
780			vec4 accum = imageLoad(accum_light, ivec3(atlas_pos, params.atlas_slice));
781			accum.rgb += light_accum / float(params.ray_count);
782			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice), accum);
783		#endif
784		
785		#endif
786		
787		#ifdef MODE_UNOCCLUDE
788		
789			//texel_size = 0.5;
790			//compute tangents
791		
792			vec4 position_alpha = imageLoad(position, ivec3(atlas_pos, params.atlas_slice));
793			if (position_alpha.a < 0.5) {
794				return;
795			}
796		
797			vec3 vertex_pos = position_alpha.xyz;
798			vec4 normal_tsize = imageLoad(unocclude, ivec3(atlas_pos, params.atlas_slice));
799		
800			vec3 face_normal = normal_tsize.xyz;
801			float texel_size = normal_tsize.w;
802		
803			vec3 v0 = abs(face_normal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
804			vec3 tangent = normalize(cross(v0, face_normal));
805			vec3 bitangent = normalize(cross(tangent, face_normal));
806			vec3 base_pos = vertex_pos + face_normal * bake_params.bias; // Raise a bit.
807		
808			vec3 rays[4] = vec3[](tangent, bitangent, -tangent, -bitangent);
809			float min_d = 1e20;
810			for (int i = 0; i < 4; i++) {
811				vec3 ray_to = base_pos + rays[i] * texel_size;
812				float d;
813				vec3 norm;
814		
815				if (trace_ray_closest_hit_distance(base_pos, ray_to, d, norm) == RAY_BACK) {
816					if (d < min_d) {
817						// This bias needs to be greater than the regular bias, because otherwise later, rays will go the other side when pointing back.
818						vertex_pos = base_pos + rays[i] * d + norm * bake_params.bias * 10.0;
819						min_d = d;
820					}
821				}
822			}
823		
824			position_alpha.xyz = vertex_pos;
825		
826			imageStore(position, ivec3(atlas_pos, params.atlas_slice), position_alpha);
827		
828		#endif
829		
830		#ifdef MODE_LIGHT_PROBES
831		
832			vec3 position = probe_positions.data[probe_index].xyz;
833		
834			vec4 probe_sh_accum[9] = vec4[](
835					vec4(0.0),
836					vec4(0.0),
837					vec4(0.0),
838					vec4(0.0),
839					vec4(0.0),
840					vec4(0.0),
841					vec4(0.0),
842					vec4(0.0),
843					vec4(0.0));
844		
845			uint noise = random_seed(ivec3(params.ray_from, probe_index, 49502741 /* some prime */));
846			for (uint i = params.ray_from; i < params.ray_to; i++) {
847				vec3 ray_dir = generate_sphere_uniform_direction(noise);
848				vec3 light = trace_indirect_light(position, ray_dir, noise);
849		
850				float c[9] = float[](
851						0.282095, //l0
852						0.488603 * ray_dir.y, //l1n1
853						0.488603 * ray_dir.z, //l1n0
854						0.488603 * ray_dir.x, //l1p1
855						1.092548 * ray_dir.x * ray_dir.y, //l2n2
856						1.092548 * ray_dir.y * ray_dir.z, //l2n1
857						//0.315392 * (ray_dir.x * ray_dir.x + ray_dir.y * ray_dir.y + 2.0 * ray_dir.z * ray_dir.z), //l20
858						0.315392 * (3.0 * ray_dir.z * ray_dir.z - 1.0), //l20
859						1.092548 * ray_dir.x * ray_dir.z, //l2p1
860						0.546274 * (ray_dir.x * ray_dir.x - ray_dir.y * ray_dir.y) //l2p2
861				);
862		
863				for (uint j = 0; j < 9; j++) {
864					probe_sh_accum[j].rgb += light * c[j];
865				}
866			}
867		
868			if (params.ray_from > 0) {
869				for (uint j = 0; j < 9; j++) { //accum from existing
870					probe_sh_accum[j] += light_probes.data[probe_index * 9 + j];
871				}
872			}
873		
874			if (params.ray_to == params.ray_count) {
875				for (uint j = 0; j < 9; j++) { //accum from existing
876					probe_sh_accum[j] *= 4.0 / float(params.ray_count);
877				}
878			}
879		
880			for (uint j = 0; j < 9; j++) { //accum from existing
881				light_probes.data[probe_index * 9 + j] = probe_sh_accum[j];
882			}
883		
884		#endif
885		
886		#ifdef MODE_DILATE
887		
888			vec4 c = texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0);
889			//sides first, as they are closer
890			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-1, 0), params.atlas_slice), 0);
891			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(0, 1), params.atlas_slice), 0);
892			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(1, 0), params.atlas_slice), 0);
893			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(0, -1), params.atlas_slice), 0);
894			//endpoints second
895			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-1, -1), params.atlas_slice), 0);
896			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-1, 1), params.atlas_slice), 0);
897			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(1, -1), params.atlas_slice), 0);
898			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(1, 1), params.atlas_slice), 0);
899		
900			//far sides third
901			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-2, 0), params.atlas_slice), 0);
902			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(0, 2), params.atlas_slice), 0);
903			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(2, 0), params.atlas_slice), 0);
904			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(0, -2), params.atlas_slice), 0);
905		
906			//far-mid endpoints
907			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-2, -1), params.atlas_slice), 0);
908			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-2, 1), params.atlas_slice), 0);
909			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(2, -1), params.atlas_slice), 0);
910			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(2, 1), params.atlas_slice), 0);
911		
912			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-1, -2), params.atlas_slice), 0);
913			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-1, 2), params.atlas_slice), 0);
914			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(1, -2), params.atlas_slice), 0);
915			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(1, 2), params.atlas_slice), 0);
916			//far endpoints
917			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-2, -2), params.atlas_slice), 0);
918			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-2, 2), params.atlas_slice), 0);
919			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(2, -2), params.atlas_slice), 0);
920			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(2, 2), params.atlas_slice), 0);
921		
922			imageStore(dest_light, ivec3(atlas_pos, params.atlas_slice), c);
923		
924		#endif
925		
926		#ifdef MODE_DENOISE
927			// Joint Non-local means (JNLM) denoiser.
928			//
929			// Based on YoctoImageDenoiser's JNLM implementation with corrections from "Nonlinearly Weighted First-order Regression for Denoising Monte Carlo Renderings".
930			//
931			// <https://github.com/ManuelPrandini/YoctoImageDenoiser/blob/06e19489dd64e47792acffde536393802ba48607/libs/yocto_extension/yocto_extension.cpp#L207>
932			// <https://benedikt-bitterli.me/nfor/nfor.pdf>
933			//
934			// MIT License
935			//
936			// Copyright (c) 2020 ManuelPrandini
937			//
938			// Permission is hereby granted, free of charge, to any person obtaining a copy
939			// of this software and associated documentation files (the "Software"), to deal
940			// in the Software without restriction, including without limitation the rights
941			// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
942			// copies of the Software, and to permit persons to whom the Software is
943			// furnished to do so, subject to the following conditions:
944			//
945			// The above copyright notice and this permission notice shall be included in all
946			// copies or substantial portions of the Software.
947			//
948			// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
949			// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
950			// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
951			// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
952			// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
953			// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
954			// SOFTWARE.
955			//
956			// Most of the constants below have been hand-picked to fit the common scenarios lightmaps
957			// are generated with, but they can be altered freely to experiment and achieve better results.
958		
959			// Half the size of the patch window around each pixel that is weighted to compute the denoised pixel.
960			// A value of 1 represents a 3x3 window, a value of 2 a 5x5 window, etc.
961			const int HALF_PATCH_WINDOW = 4;
962		
963			// Half the size of the search window around each pixel that is denoised and weighted to compute the denoised pixel.
964			const int HALF_SEARCH_WINDOW = 10;
965		
966			// For all of the following sigma values, smaller values will give less weight to pixels that have a bigger distance
967			// in the feature being evaluated. Therefore, smaller values are likely to cause more noise to appear, but will also
968			// cause less features to be erased in the process.
969		
970			// Controls how much the spatial distance of the pixels influences the denoising weight.
971			const float SIGMA_SPATIAL = denoise_params.spatial_bandwidth;
972		
973			// Controls how much the light color distance of the pixels influences the denoising weight.
974			const float SIGMA_LIGHT = denoise_params.light_bandwidth;
975		
976			// Controls how much the albedo color distance of the pixels influences the denoising weight.
977			const float SIGMA_ALBEDO = denoise_params.albedo_bandwidth;
978		
979			// Controls how much the normal vector distance of the pixels influences the denoising weight.
980			const float SIGMA_NORMAL = denoise_params.normal_bandwidth;
981		
982			// Strength of the filter. The original paper recommends values around 10 to 15 times the Sigma parameter.
983			const float FILTER_VALUE = denoise_params.filter_strength * SIGMA_LIGHT;
984		
985			// Formula constants.
986			const int PATCH_WINDOW_DIMENSION = (HALF_PATCH_WINDOW * 2 + 1);
987			const int PATCH_WINDOW_DIMENSION_SQUARE = (PATCH_WINDOW_DIMENSION * PATCH_WINDOW_DIMENSION);
988			const float TWO_SIGMA_SPATIAL_SQUARE = 2.0f * SIGMA_SPATIAL * SIGMA_SPATIAL;
989			const float TWO_SIGMA_LIGHT_SQUARE = 2.0f * SIGMA_LIGHT * SIGMA_LIGHT;
990			const float TWO_SIGMA_ALBEDO_SQUARE = 2.0f * SIGMA_ALBEDO * SIGMA_ALBEDO;
991			const float TWO_SIGMA_NORMAL_SQUARE = 2.0f * SIGMA_NORMAL * SIGMA_NORMAL;
992			const float FILTER_SQUARE_TWO_SIGMA_LIGHT_SQUARE = FILTER_VALUE * FILTER_VALUE * TWO_SIGMA_LIGHT_SQUARE;
993			const float EPSILON = 1e-6f;
994		
995		#ifdef USE_SH_LIGHTMAPS
996			const uint slice_count = 4;
997			const uint slice_base = params.atlas_slice * slice_count;
998		#else
999			const uint slice_count = 1;
1000			const uint slice_base = params.atlas_slice;
1001		#endif
1002		
1003			for (uint i = 0; i < slice_count; i++) {
1004				uint lightmap_slice = slice_base + i;
1005				vec3 denoised_rgb = vec3(0.0f);
1006				vec4 input_light = texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos, lightmap_slice), 0);
1007				vec3 input_albedo = texelFetch(sampler2DArray(albedo_tex, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).rgb;
1008				vec3 input_normal = texelFetch(sampler2DArray(source_normal, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).xyz;
1009				if (length(input_normal) > EPSILON) {
1010					// Compute the denoised pixel if the normal is valid.
1011					float sum_weights = 0.0f;
1012					vec3 input_rgb = input_light.rgb;
1013					for (int search_y = -HALF_SEARCH_WINDOW; search_y <= HALF_SEARCH_WINDOW; search_y++) {
1014						for (int search_x = -HALF_SEARCH_WINDOW; search_x <= HALF_SEARCH_WINDOW; search_x++) {
1015							ivec2 search_pos = atlas_pos + ivec2(search_x, search_y);
1016							vec3 search_rgb = texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(search_pos, lightmap_slice), 0).rgb;
1017							vec3 search_albedo = texelFetch(sampler2DArray(albedo_tex, linear_sampler), ivec3(search_pos, params.atlas_slice), 0).rgb;
1018							vec3 search_normal = texelFetch(sampler2DArray(source_normal, linear_sampler), ivec3(search_pos, params.atlas_slice), 0).xyz;
1019							float patch_square_dist = 0.0f;
1020							for (int offset_y = -HALF_PATCH_WINDOW; offset_y <= HALF_PATCH_WINDOW; offset_y++) {
1021								for (int offset_x = -HALF_PATCH_WINDOW; offset_x <= HALF_PATCH_WINDOW; offset_x++) {
1022									ivec2 offset_input_pos = atlas_pos + ivec2(offset_x, offset_y);
1023									ivec2 offset_search_pos = search_pos + ivec2(offset_x, offset_y);
1024									vec3 offset_input_rgb = texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(offset_input_pos, lightmap_slice), 0).rgb;
1025									vec3 offset_search_rgb = texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(offset_search_pos, lightmap_slice), 0).rgb;
1026									vec3 offset_delta_rgb = offset_input_rgb - offset_search_rgb;
1027									patch_square_dist += dot(offset_delta_rgb, offset_delta_rgb) - TWO_SIGMA_LIGHT_SQUARE;
1028								}
1029							}
1030		
1031							patch_square_dist = max(0.0f, patch_square_dist / (3.0f * PATCH_WINDOW_DIMENSION_SQUARE));
1032		
1033							float weight = 1.0f;
1034		
1035							// Ignore weight if search position is out of bounds.
1036							weight *= step(0, search_pos.x) * step(search_pos.x, bake_params.atlas_size.x - 1);
1037							weight *= step(0, search_pos.y) * step(search_pos.y, bake_params.atlas_size.y - 1);
1038		
1039							// Ignore weight if normal is zero length.
1040							weight *= step(EPSILON, length(search_normal));
1041		
1042							// Weight with pixel distance.
1043							vec2 pixel_delta = vec2(search_x, search_y);
1044							float pixel_square_dist = dot(pixel_delta, pixel_delta);
1045							weight *= exp(-pixel_square_dist / TWO_SIGMA_SPATIAL_SQUARE);
1046		
1047							// Weight with patch.
1048							weight *= exp(-patch_square_dist / FILTER_SQUARE_TWO_SIGMA_LIGHT_SQUARE);
1049		
1050							// Weight with albedo.
1051							vec3 albedo_delta = input_albedo - search_albedo;
1052							float albedo_square_dist = dot(albedo_delta, albedo_delta);
1053							weight *= exp(-albedo_square_dist / TWO_SIGMA_ALBEDO_SQUARE);
1054		
1055							// Weight with normal.
1056							vec3 normal_delta = input_normal - search_normal;
1057							float normal_square_dist = dot(normal_delta, normal_delta);
1058							weight *= exp(-normal_square_dist / TWO_SIGMA_NORMAL_SQUARE);
1059		
1060							denoised_rgb += weight * search_rgb;
1061							sum_weights += weight;
1062						}
1063					}
1064		
1065					denoised_rgb /= sum_weights;
1066				} else {
1067					// Ignore pixels where the normal is empty, just copy the light color.
1068					denoised_rgb = input_light.rgb;
1069				}
1070		
1071				imageStore(dest_light, ivec3(atlas_pos, lightmap_slice), vec4(denoised_rgb, input_light.a));
1072			}
1073		#endif
1074		}
1075		
1076		
          RDShaderSPIRV          ­  Failed parse:
ERROR: 0:282: 'CLUSTER_SIZE' : undeclared identifier 
ERROR: 0:282: '' : compilation terminated 
ERROR: 2 compilation errors.  No code generated.




Stage 'compute' source code: 

1		
2		#version 450
3		
4		#
5		#define MODE_DILATE
6		
7		
8		
9		// One 2D local group focusing in one layer at a time, though all
10		// in parallel (no barriers) makes more sense than a 3D local group
11		// as this can take more advantage of the cache for each group.
12		
13		#ifdef MODE_LIGHT_PROBES
14		
15		layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
16		
17		#else
18		
19		layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
20		
21		#endif
22		
23		
24		
25		/* SET 0, static data that does not change between any call */
26		
27		layout(set = 0, binding = 0) uniform BakeParameters {
28			vec3 world_size;
29			float bias;
30		
31			vec3 to_cell_offset;
32			int grid_size;
33		
34			vec3 to_cell_size;
35			uint light_count;
36		
37			mat3x4 env_transform;
38		
39			ivec2 atlas_size;
40			float exposure_normalization;
41			uint bounces;
42		
43			float bounce_indirect_energy;
44		}
45		bake_params;
46		
47		struct Vertex {
48			vec3 position;
49			float normal_z;
50			vec2 uv;
51			vec2 normal_xy;
52		};
53		
54		layout(set = 0, binding = 1, std430) restrict readonly buffer Vertices {
55			Vertex data[];
56		}
57		vertices;
58		
59		struct Triangle {
60			uvec3 indices;
61			uint slice;
62			vec3 min_bounds;
63			uint pad0;
64			vec3 max_bounds;
65			uint pad1;
66		};
67		
68		struct ClusterAABB {
69			vec3 min_bounds;
70			uint pad0;
71			vec3 max_bounds;
72			uint pad1;
73		};
74		
75		layout(set = 0, binding = 2, std430) restrict readonly buffer Triangles {
76			Triangle data[];
77		}
78		triangles;
79		
80		layout(set = 0, binding = 3, std430) restrict readonly buffer TriangleIndices {
81			uint data[];
82		}
83		triangle_indices;
84		
85		#define LIGHT_TYPE_DIRECTIONAL 0
86		#define LIGHT_TYPE_OMNI 1
87		#define LIGHT_TYPE_SPOT 2
88		
89		struct Light {
90			vec3 position;
91			uint type;
92		
93			vec3 direction;
94			float energy;
95		
96			vec3 color;
97			float size;
98		
99			float range;
100			float attenuation;
101			float cos_spot_angle;
102			float inv_spot_attenuation;
103		
104			float indirect_energy;
105			float shadow_blur;
106			bool static_bake;
107			uint pad;
108		};
109		
110		layout(set = 0, binding = 4, std430) restrict readonly buffer Lights {
111			Light data[];
112		}
113		lights;
114		
115		struct Seam {
116			uvec2 a;
117			uvec2 b;
118		};
119		
120		layout(set = 0, binding = 5, std430) restrict readonly buffer Seams {
121			Seam data[];
122		}
123		seams;
124		
125		layout(set = 0, binding = 6, std430) restrict readonly buffer Probes {
126			vec4 data[];
127		}
128		probe_positions;
129		
130		layout(set = 0, binding = 7) uniform utexture3D grid;
131		
132		layout(set = 0, binding = 8) uniform texture2DArray albedo_tex;
133		layout(set = 0, binding = 9) uniform texture2DArray emission_tex;
134		
135		layout(set = 0, binding = 10) uniform sampler linear_sampler;
136		
137		layout(set = 0, binding = 11, std430) restrict readonly buffer ClusterIndices {
138			uint data[];
139		}
140		cluster_indices;
141		
142		layout(set = 0, binding = 12, std430) restrict readonly buffer ClusterAABBs {
143			ClusterAABB data[];
144		}
145		cluster_aabbs;
146		
147		// Fragment action constants
148		const uint FA_NONE = 0;
149		const uint FA_SMOOTHEN_POSITION = 1;
150		
151		
152		#ifdef MODE_LIGHT_PROBES
153		
154		layout(set = 1, binding = 0, std430) restrict buffer LightProbeData {
155			vec4 data[];
156		}
157		light_probes;
158		
159		layout(set = 1, binding = 1) uniform texture2DArray source_light;
160		layout(set = 1, binding = 2) uniform texture2D environment;
161		#endif
162		
163		#ifdef MODE_UNOCCLUDE
164		
165		layout(rgba32f, set = 1, binding = 0) uniform restrict image2DArray position;
166		layout(rgba32f, set = 1, binding = 1) uniform restrict readonly image2DArray unocclude;
167		
168		#endif
169		
170		#if defined(MODE_DIRECT_LIGHT) || defined(MODE_BOUNCE_LIGHT)
171		
172		layout(rgba16f, set = 1, binding = 0) uniform restrict writeonly image2DArray dest_light;
173		layout(set = 1, binding = 1) uniform texture2DArray source_light;
174		layout(set = 1, binding = 2) uniform texture2DArray source_position;
175		layout(set = 1, binding = 3) uniform texture2DArray source_normal;
176		layout(rgba16f, set = 1, binding = 4) uniform restrict image2DArray accum_light;
177		
178		#endif
179		
180		#ifdef MODE_BOUNCE_LIGHT
181		layout(set = 1, binding = 5) uniform texture2D environment;
182		#endif
183		
184		#if defined(MODE_DILATE) || defined(MODE_DENOISE)
185		layout(rgba16f, set = 1, binding = 0) uniform restrict writeonly image2DArray dest_light;
186		layout(set = 1, binding = 1) uniform texture2DArray source_light;
187		#endif
188		
189		#ifdef MODE_DENOISE
190		layout(set = 1, binding = 2) uniform texture2DArray source_normal;
191		layout(set = 1, binding = 3) uniform DenoiseParams {
192			float spatial_bandwidth;
193			float light_bandwidth;
194			float albedo_bandwidth;
195			float normal_bandwidth;
196		
197			float filter_strength;
198		}
199		denoise_params;
200		#endif
201		
202		layout(push_constant, std430) uniform Params {
203			uint atlas_slice;
204			uint ray_count;
205			uint ray_from;
206			uint ray_to;
207		
208			ivec2 region_ofs;
209			uint probe_count;
210		}
211		params;
212		
213		//check it, but also return distance and barycentric coords (for uv lookup)
214		bool ray_hits_triangle(vec3 from, vec3 dir, float max_dist, vec3 p0, vec3 p1, vec3 p2, out float r_distance, out vec3 r_barycentric) {
215			const float EPSILON = 0.00001;
216			const vec3 e0 = p1 - p0;
217			const vec3 e1 = p0 - p2;
218			vec3 triangle_normal = cross(e1, e0);
219		
220			float n_dot_dir = dot(triangle_normal, dir);
221		
222			if (abs(n_dot_dir) < EPSILON) {
223				return false;
224			}
225		
226			const vec3 e2 = (p0 - from) / n_dot_dir;
227			const vec3 i = cross(dir, e2);
228		
229			r_barycentric.y = dot(i, e1);
230			r_barycentric.z = dot(i, e0);
231			r_barycentric.x = 1.0 - (r_barycentric.z + r_barycentric.y);
232			r_distance = dot(triangle_normal, e2);
233		
234			return (r_distance > bake_params.bias) && (r_distance < max_dist) && all(greaterThanEqual(r_barycentric, vec3(0.0)));
235		}
236		
237		const uint RAY_MISS = 0;
238		const uint RAY_FRONT = 1;
239		const uint RAY_BACK = 2;
240		const uint RAY_ANY = 3;
241		
242		bool ray_box_test(vec3 p_from, vec3 p_inv_dir, vec3 p_box_min, vec3 p_box_max) {
243			vec3 t0 = (p_box_min - p_from) * p_inv_dir;
244			vec3 t1 = (p_box_max - p_from) * p_inv_dir;
245			vec3 tmin = min(t0, t1), tmax = max(t0, t1);
246			return max(tmin.x, max(tmin.y, tmin.z)) <= min(tmax.x, min(tmax.y, tmax.z));
247		}
248		
249		#if CLUSTER_SIZE > 32
250		#define CLUSTER_TRIANGLE_ITERATION
251		#endif
252		
253		uint trace_ray(vec3 p_from, vec3 p_to, bool p_any_hit, out float r_distance, out vec3 r_normal, out uint r_triangle, out vec3 r_barycentric) {
254			// World coordinates.
255			vec3 rel = p_to - p_from;
256			float rel_len = length(rel);
257			vec3 dir = normalize(rel);
258			vec3 inv_dir = 1.0 / dir;
259		
260			// Cell coordinates.
261			vec3 from_cell = (p_from - bake_params.to_cell_offset) * bake_params.to_cell_size;
262			vec3 to_cell = (p_to - bake_params.to_cell_offset) * bake_params.to_cell_size;
263		
264			// Prepare DDA.
265			vec3 rel_cell = to_cell - from_cell;
266			ivec3 icell = ivec3(from_cell);
267			ivec3 iendcell = ivec3(to_cell);
268			vec3 dir_cell = normalize(rel_cell);
269			vec3 delta = min(abs(1.0 / dir_cell), bake_params.grid_size); // Use bake_params.grid_size as max to prevent infinity values.
270			ivec3 step = ivec3(sign(rel_cell));
271			vec3 side = (sign(rel_cell) * (vec3(icell) - from_cell) + (sign(rel_cell) * 0.5) + 0.5) * delta;
272		
273			uint iters = 0;
274			while (all(greaterThanEqual(icell, ivec3(0))) && all(lessThan(icell, ivec3(bake_params.grid_size))) && (iters < 1000)) {
275				uvec2 cell_data = texelFetch(usampler3D(grid, linear_sampler), icell, 0).xy;
276				uint triangle_count = cell_data.x;
277				if (triangle_count > 0) {
278					uint hit = RAY_MISS;
279					float best_distance = 1e20;
280					uint cluster_start = cluster_indices.data[cell_data.y * 2];
281					uint cell_triangle_start = cluster_indices.data[cell_data.y * 2 + 1];
282					uint cluster_count = (triangle_count + CLUSTER_SIZE - 1) / CLUSTER_SIZE;
283					uint cluster_base_index = 0;
284					while (cluster_base_index < cluster_count) {
285						// To minimize divergence, all Ray-AABB tests on the clusters contained in the cell are performed
286						// before checking against the triangles. We do this 32 clusters at a time and store the intersected
287						// clusters on each bit of the 32-bit integer.
288						uint cluster_test_count = min(32, cluster_count - cluster_base_index);
289						uint cluster_hits = 0;
290						for (uint i = 0; i < cluster_test_count; i++) {
291							uint cluster_index = cluster_start + cluster_base_index + i;
292							ClusterAABB cluster_aabb = cluster_aabbs.data[cluster_index];
293							if (ray_box_test(p_from, inv_dir, cluster_aabb.min_bounds, cluster_aabb.max_bounds)) {
294								cluster_hits |= (1 << i);
295							}
296						}
297		
298						// Check the triangles in any of the clusters that were intersected by toggling off the bits in the
299						// 32-bit integer counter until no bits are left.
300						while (cluster_hits > 0) {
301							uint cluster_index = findLSB(cluster_hits);
302							cluster_hits &= ~(1 << cluster_index);
303							cluster_index += cluster_base_index;
304		
305							// Do the same divergence execution trick with triangles as well.
306							uint triangle_base_index = 0;
307		#ifdef CLUSTER_TRIANGLE_ITERATION
308							while (triangle_base_index < triangle_count)
309		#endif
310							{
311								uint triangle_start_index = cell_triangle_start + cluster_index * CLUSTER_SIZE + triangle_base_index;
312								uint triangle_test_count = min(CLUSTER_SIZE, triangle_count - triangle_base_index);
313								uint triangle_hits = 0;
314								for (uint i = 0; i < triangle_test_count; i++) {
315									uint triangle_index = triangle_indices.data[triangle_start_index + i];
316									if (ray_box_test(p_from, inv_dir, triangles.data[triangle_index].min_bounds, triangles.data[triangle_index].max_bounds)) {
317										triangle_hits |= (1 << i);
318									}
319								}
320		
321								while (triangle_hits > 0) {
322									uint cluster_triangle_index = findLSB(triangle_hits);
323									triangle_hits &= ~(1 << cluster_triangle_index);
324									cluster_triangle_index += triangle_start_index;
325		
326									uint triangle_index = triangle_indices.data[cluster_triangle_index];
327									Triangle triangle = triangles.data[triangle_index];
328		
329									// Gather the triangle vertex positions.
330									vec3 vtx0 = vertices.data[triangle.indices.x].position;
331									vec3 vtx1 = vertices.data[triangle.indices.y].position;
332									vec3 vtx2 = vertices.data[triangle.indices.z].position;
333									vec3 normal = -normalize(cross((vtx0 - vtx1), (vtx0 - vtx2)));
334									bool backface = dot(normal, dir) >= 0.0;
335									float distance;
336									vec3 barycentric;
337									if (ray_hits_triangle(p_from, dir, rel_len, vtx0, vtx1, vtx2, distance, barycentric)) {
338										if (p_any_hit) {
339											// Return early if any hit was requested.
340											return RAY_ANY;
341										}
342		
343										vec3 position = p_from + dir * distance;
344										vec3 hit_cell = (position - bake_params.to_cell_offset) * bake_params.to_cell_size;
345										if (icell != ivec3(hit_cell)) {
346											// It's possible for the ray to hit a triangle in a position outside the bounds of the cell
347											// if it's large enough to cover multiple ones. The hit must be ignored if this is the case.
348											continue;
349										}
350		
351										if (!backface) {
352											// The case of meshes having both a front and back face in the same plane is more common than
353											// expected, so if this is a front-face, bias it closer to the ray origin, so it always wins
354											// over the back-face.
355											distance = max(bake_params.bias, distance - bake_params.bias);
356										}
357		
358										if (distance < best_distance) {
359											hit = backface ? RAY_BACK : RAY_FRONT;
360											best_distance = distance;
361											r_distance = distance;
362											r_normal = normal;
363											r_triangle = triangle_index;
364											r_barycentric = barycentric;
365										}
366									}
367								}
368		
369		#ifdef CLUSTER_TRIANGLE_ITERATION
370								triangle_base_index += CLUSTER_SIZE;
371		#endif
372							}
373						}
374		
375						cluster_base_index += 32;
376					}
377		
378					if (hit != RAY_MISS) {
379						return hit;
380					}
381				}
382		
383				if (icell == iendcell) {
384					break;
385				}
386		
387				bvec3 mask = lessThanEqual(side.xyz, min(side.yzx, side.zxy));
388				side += vec3(mask) * delta;
389				icell += ivec3(vec3(mask)) * step;
390				iters++;
391			}
392		
393			return RAY_MISS;
394		}
395		
396		uint trace_ray_closest_hit_triangle(vec3 p_from, vec3 p_to, out uint r_triangle, out vec3 r_barycentric) {
397			float distance;
398			vec3 normal;
399			return trace_ray(p_from, p_to, false, distance, normal, r_triangle, r_barycentric);
400		}
401		
402		uint trace_ray_closest_hit_distance(vec3 p_from, vec3 p_to, out float r_distance, out vec3 r_normal) {
403			uint triangle;
404			vec3 barycentric;
405			return trace_ray(p_from, p_to, false, r_distance, r_normal, triangle, barycentric);
406		}
407		
408		uint trace_ray_any_hit(vec3 p_from, vec3 p_to) {
409			float distance;
410			vec3 normal;
411			uint triangle;
412			vec3 barycentric;
413			return trace_ray(p_from, p_to, true, distance, normal, triangle, barycentric);
414		}
415		
416		// https://www.reedbeta.com/blog/hash-functions-for-gpu-rendering/
417		uint hash(uint value) {
418			uint state = value * 747796405u + 2891336453u;
419			uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
420			return (word >> 22u) ^ word;
421		}
422		
423		uint random_seed(ivec3 seed) {
424			return hash(seed.x ^ hash(seed.y ^ hash(seed.z)));
425		}
426		
427		// generates a random value in range [0.0, 1.0)
428		float randomize(inout uint value) {
429			value = hash(value);
430			return float(value / 4294967296.0);
431		}
432		
433		const float PI = 3.14159265f;
434		
435		// http://www.realtimerendering.com/raytracinggems/unofficial_RayTracingGems_v1.4.pdf (chapter 15)
436		vec3 generate_hemisphere_cosine_weighted_direction(inout uint noise) {
437			float noise1 = randomize(noise);
438			float noise2 = randomize(noise) * 2.0 * PI;
439		
440			return vec3(sqrt(noise1) * cos(noise2), sqrt(noise1) * sin(noise2), sqrt(1.0 - noise1));
441		}
442		
443		// Distribution generation adapted from "Generating uniformly distributed numbers on a sphere"
444		// <http://corysimon.github.io/articles/uniformdistn-on-sphere/>
445		vec3 generate_sphere_uniform_direction(inout uint noise) {
446			float theta = 2.0 * PI * randomize(noise);
447			float phi = acos(1.0 - 2.0 * randomize(noise));
448			return vec3(sin(phi) * cos(theta), sin(phi) * sin(theta), cos(phi));
449		}
450		
451		vec3 generate_ray_dir_from_normal(vec3 normal, inout uint noise) {
452			vec3 v0 = abs(normal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
453			vec3 tangent = normalize(cross(v0, normal));
454			vec3 bitangent = normalize(cross(tangent, normal));
455			mat3 normal_mat = mat3(tangent, bitangent, normal);
456			return normal_mat * generate_hemisphere_cosine_weighted_direction(noise);
457		}
458		
459		#if defined(MODE_DIRECT_LIGHT) || defined(MODE_BOUNCE_LIGHT) || defined(MODE_LIGHT_PROBES)
460		
461		float get_omni_attenuation(float distance, float inv_range, float decay) {
462			float nd = distance * inv_range;
463			nd *= nd;
464			nd *= nd; // nd^4
465			nd = max(1.0 - nd, 0.0);
466			nd *= nd; // nd^2
467			return nd * pow(max(distance, 0.0001), -decay);
468		}
469		
470		void trace_direct_light(vec3 p_position, vec3 p_normal, uint p_light_index, bool p_soft_shadowing, out vec3 r_light, out vec3 r_light_dir, inout uint r_noise) {
471			r_light = vec3(0.0f);
472		
473			vec3 light_pos;
474			float dist;
475			float attenuation;
476			float soft_shadowing_disk_size;
477			Light light_data = lights.data[p_light_index];
478			if (light_data.type == LIGHT_TYPE_DIRECTIONAL) {
479				vec3 light_vec = light_data.direction;
480				light_pos = p_position - light_vec * length(bake_params.world_size);
481				r_light_dir = normalize(light_pos - p_position);
482				dist = length(bake_params.world_size);
483				attenuation = 1.0;
484				soft_shadowing_disk_size = light_data.size;
485			} else {
486				light_pos = light_data.position;
487				r_light_dir = normalize(light_pos - p_position);
488				dist = distance(p_position, light_pos);
489				if (dist > light_data.range) {
490					return;
491				}
492		
493				soft_shadowing_disk_size = light_data.size / dist;
494		
495				attenuation = get_omni_attenuation(dist, 1.0 / light_data.range, light_data.attenuation);
496		
497				if (light_data.type == LIGHT_TYPE_SPOT) {
498					vec3 rel = normalize(p_position - light_pos);
499					float cos_spot_angle = light_data.cos_spot_angle;
500					float cos_angle = dot(rel, light_data.direction);
501		
502					if (cos_angle < cos_spot_angle) {
503						return;
504					}
505		
506					float scos = max(cos_angle, cos_spot_angle);
507					float spot_rim = max(0.0001, (1.0 - scos) / (1.0 - cos_spot_angle));
508					attenuation *= 1.0 - pow(spot_rim, light_data.inv_spot_attenuation);
509				}
510			}
511		
512			attenuation *= max(0.0, dot(p_normal, r_light_dir));
513			if (attenuation <= 0.0001) {
514				return;
515			}
516		
517			float penumbra = 0.0;
518			if ((light_data.size > 0.0) && p_soft_shadowing) {
519				vec3 light_to_point = -r_light_dir;
520				vec3 aux = light_to_point.y < 0.777 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
521				vec3 light_to_point_tan = normalize(cross(light_to_point, aux));
522				vec3 light_to_point_bitan = normalize(cross(light_to_point, light_to_point_tan));
523		
524				const uint shadowing_rays_check_penumbra_denom = 2;
525				uint shadowing_ray_count = p_soft_shadowing ? params.ray_count : 1;
526		
527				uint hits = 0;
528				vec3 light_disk_to_point = light_to_point;
529				for (uint j = 0; j < shadowing_ray_count; j++) {
530					// Optimization:
531					// Once already traced an important proportion of rays, if all are hits or misses,
532					// assume we're not in the penumbra so we can infer the rest would have the same result
533					if (p_soft_shadowing) {
534						if (j == shadowing_ray_count / shadowing_rays_check_penumbra_denom) {
535							if (hits == j) {
536								// Assume totally lit
537								hits = shadowing_ray_count;
538								break;
539							} else if (hits == 0) {
540								// Assume totally dark
541								hits = 0;
542								break;
543							}
544						}
545					}
546		
547					float r = randomize(r_noise);
548					float a = randomize(r_noise) * 2.0 * PI;
549					vec2 disk_sample = (r * vec2(cos(a), sin(a))) * soft_shadowing_disk_size * light_data.shadow_blur;
550					light_disk_to_point = normalize(light_to_point + disk_sample.x * light_to_point_tan + disk_sample.y * light_to_point_bitan);
551		
552					if (trace_ray_any_hit(p_position - light_disk_to_point * bake_params.bias, p_position - light_disk_to_point * dist) == RAY_MISS) {
553						hits++;
554					}
555				}
556		
557				penumbra = float(hits) / float(shadowing_ray_count);
558			} else {
559				if (trace_ray_any_hit(p_position + r_light_dir * bake_params.bias, light_pos) == RAY_MISS) {
560					penumbra = 1.0;
561				}
562			}
563		
564			r_light = light_data.color * light_data.energy * attenuation * penumbra;
565		}
566		
567		#endif
568		
569		#if defined(MODE_BOUNCE_LIGHT) || defined(MODE_LIGHT_PROBES)
570		
571		vec3 trace_environment_color(vec3 ray_dir) {
572			vec3 sky_dir = normalize(mat3(bake_params.env_transform) * ray_dir);
573			vec2 st = vec2(atan(sky_dir.x, sky_dir.z), acos(sky_dir.y));
574			if (st.x < 0.0) {
575				st.x += PI * 2.0;
576			}
577		
578			return textureLod(sampler2D(environment, linear_sampler), st / vec2(PI * 2.0, PI), 0.0).rgb;
579		}
580		
581		vec3 trace_indirect_light(vec3 p_position, vec3 p_ray_dir, inout uint r_noise) {
582			// The lower limit considers the case where the lightmapper might have bounces disabled but light probes are requested.
583			vec3 position = p_position;
584			vec3 ray_dir = p_ray_dir;
585			uint max_depth = max(bake_params.bounces, 1);
586			vec3 throughput = vec3(1.0);
587			vec3 light = vec3(0.0);
588			for (uint depth = 0; depth < max_depth; depth++) {
589				uint tidx;
590				vec3 barycentric;
591				uint trace_result = trace_ray_closest_hit_triangle(position + ray_dir * bake_params.bias, position + ray_dir * length(bake_params.world_size), tidx, barycentric);
592				if (trace_result == RAY_FRONT) {
593					Vertex vert0 = vertices.data[triangles.data[tidx].indices.x];
594					Vertex vert1 = vertices.data[triangles.data[tidx].indices.y];
595					Vertex vert2 = vertices.data[triangles.data[tidx].indices.z];
596					vec3 uvw = vec3(barycentric.x * vert0.uv + barycentric.y * vert1.uv + barycentric.z * vert2.uv, float(triangles.data[tidx].slice));
597					position = barycentric.x * vert0.position + barycentric.y * vert1.position + barycentric.z * vert2.position;
598		
599					vec3 norm0 = vec3(vert0.normal_xy, vert0.normal_z);
600					vec3 norm1 = vec3(vert1.normal_xy, vert1.normal_z);
601					vec3 norm2 = vec3(vert2.normal_xy, vert2.normal_z);
602					vec3 normal = barycentric.x * norm0 + barycentric.y * norm1 + barycentric.z * norm2;
603		
604					vec3 direct_light = vec3(0.0f);
605		#ifdef USE_LIGHT_TEXTURE_FOR_BOUNCES
606					direct_light += textureLod(sampler2DArray(source_light, linear_sampler), uvw, 0.0).rgb;
607		#else
608					// Trace the lights directly. Significantly more expensive but more accurate in scenarios
609					// where the lightmap texture isn't reliable.
610					for (uint i = 0; i < bake_params.light_count; i++) {
611						vec3 light;
612						vec3 light_dir;
613						trace_direct_light(position, normal, i, false, light, light_dir, r_noise);
614						direct_light += light * lights.data[i].indirect_energy;
615					}
616		
617					direct_light *= bake_params.exposure_normalization;
618		#endif
619		
620					vec3 albedo = textureLod(sampler2DArray(albedo_tex, linear_sampler), uvw, 0).rgb;
621					vec3 emissive = textureLod(sampler2DArray(emission_tex, linear_sampler), uvw, 0).rgb;
622					emissive *= bake_params.exposure_normalization;
623		
624					light += throughput * emissive;
625					throughput *= albedo;
626					light += throughput * direct_light * bake_params.bounce_indirect_energy;
627		
628					// Use Russian Roulette to determine a probability to terminate the bounce earlier as an optimization.
629					// <https://computergraphics.stackexchange.com/questions/2316/is-russian-roulette-really-the-answer>
630					float p = max(max(throughput.x, throughput.y), throughput.z);
631					if (randomize(r_noise) > p) {
632						break;
633					}
634		
635					// Boost the throughput from the probability of the ray being terminated early.
636					throughput *= 1.0 / p;
637		
638					// Generate a new ray direction for the next bounce from this surface's normal.
639					ray_dir = generate_ray_dir_from_normal(normal, r_noise);
640				} else if (trace_result == RAY_MISS) {
641					// Look for the environment color and stop bouncing.
642					light += throughput * trace_environment_color(ray_dir);
643					break;
644				} else {
645					// Ignore any other trace results.
646					break;
647				}
648			}
649		
650			return light;
651		}
652		
653		#endif
654		
655		void main() {
656			// Check if invocation is out of bounds.
657		#ifdef MODE_LIGHT_PROBES
658			int probe_index = int(gl_GlobalInvocationID.x);
659			if (probe_index >= params.probe_count) {
660				return;
661			}
662		
663		#else
664			ivec2 atlas_pos = ivec2(gl_GlobalInvocationID.xy) + params.region_ofs;
665			if (any(greaterThanEqual(atlas_pos, bake_params.atlas_size))) {
666				return;
667			}
668		#endif
669		
670		#ifdef MODE_DIRECT_LIGHT
671		
672			vec3 normal = texelFetch(sampler2DArray(source_normal, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).xyz;
673			if (length(normal) < 0.5) {
674				return; //empty texel, no process
675			}
676			vec3 position = texelFetch(sampler2DArray(source_position, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).xyz;
677			vec3 light_for_texture = vec3(0.0);
678			vec3 light_for_bounces = vec3(0.0);
679		
680		#ifdef USE_SH_LIGHTMAPS
681			vec4 sh_accum[4] = vec4[](
682					vec4(0.0, 0.0, 0.0, 1.0),
683					vec4(0.0, 0.0, 0.0, 1.0),
684					vec4(0.0, 0.0, 0.0, 1.0),
685					vec4(0.0, 0.0, 0.0, 1.0));
686		#endif
687		
688			// Use atlas position and a prime number as the seed.
689			uint noise = random_seed(ivec3(atlas_pos, 43573547));
690			for (uint i = 0; i < bake_params.light_count; i++) {
691				vec3 light;
692				vec3 light_dir;
693				trace_direct_light(position, normal, i, true, light, light_dir, noise);
694		
695				if (lights.data[i].static_bake) {
696					light_for_texture += light;
697		
698		#ifdef USE_SH_LIGHTMAPS
699					float c[4] = float[](
700							0.282095, //l0
701							0.488603 * light_dir.y, //l1n1
702							0.488603 * light_dir.z, //l1n0
703							0.488603 * light_dir.x //l1p1
704					);
705		
706					for (uint j = 0; j < 4; j++) {
707						sh_accum[j].rgb += light * c[j] * 8.0;
708					}
709		#endif
710				}
711		
712				light_for_bounces += light * lights.data[i].indirect_energy;
713			}
714		
715			light_for_bounces *= bake_params.exposure_normalization;
716			imageStore(dest_light, ivec3(atlas_pos, params.atlas_slice), vec4(light_for_bounces, 1.0));
717		
718		#ifdef USE_SH_LIGHTMAPS
719			// Keep for adding at the end.
720			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + 0), sh_accum[0]);
721			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + 1), sh_accum[1]);
722			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + 2), sh_accum[2]);
723			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + 3), sh_accum[3]);
724		#else
725			light_for_texture *= bake_params.exposure_normalization;
726			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice), vec4(light_for_texture, 1.0));
727		#endif
728		
729		#endif
730		
731		#ifdef MODE_BOUNCE_LIGHT
732		
733		#ifdef USE_SH_LIGHTMAPS
734			vec4 sh_accum[4] = vec4[](
735					vec4(0.0, 0.0, 0.0, 1.0),
736					vec4(0.0, 0.0, 0.0, 1.0),
737					vec4(0.0, 0.0, 0.0, 1.0),
738					vec4(0.0, 0.0, 0.0, 1.0));
739		#else
740			vec3 light_accum = vec3(0.0);
741		#endif
742		
743			// Retrieve starting normal and position.
744			vec3 normal = texelFetch(sampler2DArray(source_normal, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).xyz;
745			if (length(normal) < 0.5) {
746				// The pixel is empty, skip processing it.
747				return;
748			}
749		
750			vec3 position = texelFetch(sampler2DArray(source_position, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).xyz;
751			uint noise = random_seed(ivec3(params.ray_from, atlas_pos));
752			for (uint i = params.ray_from; i < params.ray_to; i++) {
753				vec3 ray_dir = generate_ray_dir_from_normal(normal, noise);
754				vec3 light = trace_indirect_light(position, ray_dir, noise);
755		
756		#ifdef USE_SH_LIGHTMAPS
757				float c[4] = float[](
758						0.282095, //l0
759						0.488603 * ray_dir.y, //l1n1
760						0.488603 * ray_dir.z, //l1n0
761						0.488603 * ray_dir.x //l1p1
762				);
763		
764				for (uint j = 0; j < 4; j++) {
765					sh_accum[j].rgb += light * c[j] * 8.0;
766				}
767		#else
768				light_accum += light;
769		#endif
770			}
771		
772			// Add the averaged result to the accumulated light texture.
773		#ifdef USE_SH_LIGHTMAPS
774			for (int i = 0; i < 4; i++) {
775				vec4 accum = imageLoad(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + i));
776				accum.rgb += sh_accum[i].rgb / float(params.ray_count);
777				imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + i), accum);
778			}
779		#else
780			vec4 accum = imageLoad(accum_light, ivec3(atlas_pos, params.atlas_slice));
781			accum.rgb += light_accum / float(params.ray_count);
782			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice), accum);
783		#endif
784		
785		#endif
786		
787		#ifdef MODE_UNOCCLUDE
788		
789			//texel_size = 0.5;
790			//compute tangents
791		
792			vec4 position_alpha = imageLoad(position, ivec3(atlas_pos, params.atlas_slice));
793			if (position_alpha.a < 0.5) {
794				return;
795			}
796		
797			vec3 vertex_pos = position_alpha.xyz;
798			vec4 normal_tsize = imageLoad(unocclude, ivec3(atlas_pos, params.atlas_slice));
799		
800			vec3 face_normal = normal_tsize.xyz;
801			float texel_size = normal_tsize.w;
802		
803			vec3 v0 = abs(face_normal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
804			vec3 tangent = normalize(cross(v0, face_normal));
805			vec3 bitangent = normalize(cross(tangent, face_normal));
806			vec3 base_pos = vertex_pos + face_normal * bake_params.bias; // Raise a bit.
807		
808			vec3 rays[4] = vec3[](tangent, bitangent, -tangent, -bitangent);
809			float min_d = 1e20;
810			for (int i = 0; i < 4; i++) {
811				vec3 ray_to = base_pos + rays[i] * texel_size;
812				float d;
813				vec3 norm;
814		
815				if (trace_ray_closest_hit_distance(base_pos, ray_to, d, norm) == RAY_BACK) {
816					if (d < min_d) {
817						// This bias needs to be greater than the regular bias, because otherwise later, rays will go the other side when pointing back.
818						vertex_pos = base_pos + rays[i] * d + norm * bake_params.bias * 10.0;
819						min_d = d;
820					}
821				}
822			}
823		
824			position_alpha.xyz = vertex_pos;
825		
826			imageStore(position, ivec3(atlas_pos, params.atlas_slice), position_alpha);
827		
828		#endif
829		
830		#ifdef MODE_LIGHT_PROBES
831		
832			vec3 position = probe_positions.data[probe_index].xyz;
833		
834			vec4 probe_sh_accum[9] = vec4[](
835					vec4(0.0),
836					vec4(0.0),
837					vec4(0.0),
838					vec4(0.0),
839					vec4(0.0),
840					vec4(0.0),
841					vec4(0.0),
842					vec4(0.0),
843					vec4(0.0));
844		
845			uint noise = random_seed(ivec3(params.ray_from, probe_index, 49502741 /* some prime */));
846			for (uint i = params.ray_from; i < params.ray_to; i++) {
847				vec3 ray_dir = generate_sphere_uniform_direction(noise);
848				vec3 light = trace_indirect_light(position, ray_dir, noise);
849		
850				float c[9] = float[](
851						0.282095, //l0
852						0.488603 * ray_dir.y, //l1n1
853						0.488603 * ray_dir.z, //l1n0
854						0.488603 * ray_dir.x, //l1p1
855						1.092548 * ray_dir.x * ray_dir.y, //l2n2
856						1.092548 * ray_dir.y * ray_dir.z, //l2n1
857						//0.315392 * (ray_dir.x * ray_dir.x + ray_dir.y * ray_dir.y + 2.0 * ray_dir.z * ray_dir.z), //l20
858						0.315392 * (3.0 * ray_dir.z * ray_dir.z - 1.0), //l20
859						1.092548 * ray_dir.x * ray_dir.z, //l2p1
860						0.546274 * (ray_dir.x * ray_dir.x - ray_dir.y * ray_dir.y) //l2p2
861				);
862		
863				for (uint j = 0; j < 9; j++) {
864					probe_sh_accum[j].rgb += light * c[j];
865				}
866			}
867		
868			if (params.ray_from > 0) {
869				for (uint j = 0; j < 9; j++) { //accum from existing
870					probe_sh_accum[j] += light_probes.data[probe_index * 9 + j];
871				}
872			}
873		
874			if (params.ray_to == params.ray_count) {
875				for (uint j = 0; j < 9; j++) { //accum from existing
876					probe_sh_accum[j] *= 4.0 / float(params.ray_count);
877				}
878			}
879		
880			for (uint j = 0; j < 9; j++) { //accum from existing
881				light_probes.data[probe_index * 9 + j] = probe_sh_accum[j];
882			}
883		
884		#endif
885		
886		#ifdef MODE_DILATE
887		
888			vec4 c = texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0);
889			//sides first, as they are closer
890			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-1, 0), params.atlas_slice), 0);
891			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(0, 1), params.atlas_slice), 0);
892			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(1, 0), params.atlas_slice), 0);
893			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(0, -1), params.atlas_slice), 0);
894			//endpoints second
895			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-1, -1), params.atlas_slice), 0);
896			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-1, 1), params.atlas_slice), 0);
897			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(1, -1), params.atlas_slice), 0);
898			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(1, 1), params.atlas_slice), 0);
899		
900			//far sides third
901			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-2, 0), params.atlas_slice), 0);
902			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(0, 2), params.atlas_slice), 0);
903			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(2, 0), params.atlas_slice), 0);
904			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(0, -2), params.atlas_slice), 0);
905		
906			//far-mid endpoints
907			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-2, -1), params.atlas_slice), 0);
908			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-2, 1), params.atlas_slice), 0);
909			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(2, -1), params.atlas_slice), 0);
910			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(2, 1), params.atlas_slice), 0);
911		
912			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-1, -2), params.atlas_slice), 0);
913			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-1, 2), params.atlas_slice), 0);
914			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(1, -2), params.atlas_slice), 0);
915			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(1, 2), params.atlas_slice), 0);
916			//far endpoints
917			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-2, -2), params.atlas_slice), 0);
918			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-2, 2), params.atlas_slice), 0);
919			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(2, -2), params.atlas_slice), 0);
920			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(2, 2), params.atlas_slice), 0);
921		
922			imageStore(dest_light, ivec3(atlas_pos, params.atlas_slice), c);
923		
924		#endif
925		
926		#ifdef MODE_DENOISE
927			// Joint Non-local means (JNLM) denoiser.
928			//
929			// Based on YoctoImageDenoiser's JNLM implementation with corrections from "Nonlinearly Weighted First-order Regression for Denoising Monte Carlo Renderings".
930			//
931			// <https://github.com/ManuelPrandini/YoctoImageDenoiser/blob/06e19489dd64e47792acffde536393802ba48607/libs/yocto_extension/yocto_extension.cpp#L207>
932			// <https://benedikt-bitterli.me/nfor/nfor.pdf>
933			//
934			// MIT License
935			//
936			// Copyright (c) 2020 ManuelPrandini
937			//
938			// Permission is hereby granted, free of charge, to any person obtaining a copy
939			// of this software and associated documentation files (the "Software"), to deal
940			// in the Software without restriction, including without limitation the rights
941			// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
942			// copies of the Software, and to permit persons to whom the Software is
943			// furnished to do so, subject to the following conditions:
944			//
945			// The above copyright notice and this permission notice shall be included in all
946			// copies or substantial portions of the Software.
947			//
948			// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
949			// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
950			// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
951			// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
952			// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
953			// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
954			// SOFTWARE.
955			//
956			// Most of the constants below have been hand-picked to fit the common scenarios lightmaps
957			// are generated with, but they can be altered freely to experiment and achieve better results.
958		
959			// Half the size of the patch window around each pixel that is weighted to compute the denoised pixel.
960			// A value of 1 represents a 3x3 window, a value of 2 a 5x5 window, etc.
961			const int HALF_PATCH_WINDOW = 4;
962		
963			// Half the size of the search window around each pixel that is denoised and weighted to compute the denoised pixel.
964			const int HALF_SEARCH_WINDOW = 10;
965		
966			// For all of the following sigma values, smaller values will give less weight to pixels that have a bigger distance
967			// in the feature being evaluated. Therefore, smaller values are likely to cause more noise to appear, but will also
968			// cause less features to be erased in the process.
969		
970			// Controls how much the spatial distance of the pixels influences the denoising weight.
971			const float SIGMA_SPATIAL = denoise_params.spatial_bandwidth;
972		
973			// Controls how much the light color distance of the pixels influences the denoising weight.
974			const float SIGMA_LIGHT = denoise_params.light_bandwidth;
975		
976			// Controls how much the albedo color distance of the pixels influences the denoising weight.
977			const float SIGMA_ALBEDO = denoise_params.albedo_bandwidth;
978		
979			// Controls how much the normal vector distance of the pixels influences the denoising weight.
980			const float SIGMA_NORMAL = denoise_params.normal_bandwidth;
981		
982			// Strength of the filter. The original paper recommends values around 10 to 15 times the Sigma parameter.
983			const float FILTER_VALUE = denoise_params.filter_strength * SIGMA_LIGHT;
984		
985			// Formula constants.
986			const int PATCH_WINDOW_DIMENSION = (HALF_PATCH_WINDOW * 2 + 1);
987			const int PATCH_WINDOW_DIMENSION_SQUARE = (PATCH_WINDOW_DIMENSION * PATCH_WINDOW_DIMENSION);
988			const float TWO_SIGMA_SPATIAL_SQUARE = 2.0f * SIGMA_SPATIAL * SIGMA_SPATIAL;
989			const float TWO_SIGMA_LIGHT_SQUARE = 2.0f * SIGMA_LIGHT * SIGMA_LIGHT;
990			const float TWO_SIGMA_ALBEDO_SQUARE = 2.0f * SIGMA_ALBEDO * SIGMA_ALBEDO;
991			const float TWO_SIGMA_NORMAL_SQUARE = 2.0f * SIGMA_NORMAL * SIGMA_NORMAL;
992			const float FILTER_SQUARE_TWO_SIGMA_LIGHT_SQUARE = FILTER_VALUE * FILTER_VALUE * TWO_SIGMA_LIGHT_SQUARE;
993			const float EPSILON = 1e-6f;
994		
995		#ifdef USE_SH_LIGHTMAPS
996			const uint slice_count = 4;
997			const uint slice_base = params.atlas_slice * slice_count;
998		#else
999			const uint slice_count = 1;
1000			const uint slice_base = params.atlas_slice;
1001		#endif
1002		
1003			for (uint i = 0; i < slice_count; i++) {
1004				uint lightmap_slice = slice_base + i;
1005				vec3 denoised_rgb = vec3(0.0f);
1006				vec4 input_light = texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos, lightmap_slice), 0);
1007				vec3 input_albedo = texelFetch(sampler2DArray(albedo_tex, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).rgb;
1008				vec3 input_normal = texelFetch(sampler2DArray(source_normal, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).xyz;
1009				if (length(input_normal) > EPSILON) {
1010					// Compute the denoised pixel if the normal is valid.
1011					float sum_weights = 0.0f;
1012					vec3 input_rgb = input_light.rgb;
1013					for (int search_y = -HALF_SEARCH_WINDOW; search_y <= HALF_SEARCH_WINDOW; search_y++) {
1014						for (int search_x = -HALF_SEARCH_WINDOW; search_x <= HALF_SEARCH_WINDOW; search_x++) {
1015							ivec2 search_pos = atlas_pos + ivec2(search_x, search_y);
1016							vec3 search_rgb = texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(search_pos, lightmap_slice), 0).rgb;
1017							vec3 search_albedo = texelFetch(sampler2DArray(albedo_tex, linear_sampler), ivec3(search_pos, params.atlas_slice), 0).rgb;
1018							vec3 search_normal = texelFetch(sampler2DArray(source_normal, linear_sampler), ivec3(search_pos, params.atlas_slice), 0).xyz;
1019							float patch_square_dist = 0.0f;
1020							for (int offset_y = -HALF_PATCH_WINDOW; offset_y <= HALF_PATCH_WINDOW; offset_y++) {
1021								for (int offset_x = -HALF_PATCH_WINDOW; offset_x <= HALF_PATCH_WINDOW; offset_x++) {
1022									ivec2 offset_input_pos = atlas_pos + ivec2(offset_x, offset_y);
1023									ivec2 offset_search_pos = search_pos + ivec2(offset_x, offset_y);
1024									vec3 offset_input_rgb = texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(offset_input_pos, lightmap_slice), 0).rgb;
1025									vec3 offset_search_rgb = texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(offset_search_pos, lightmap_slice), 0).rgb;
1026									vec3 offset_delta_rgb = offset_input_rgb - offset_search_rgb;
1027									patch_square_dist += dot(offset_delta_rgb, offset_delta_rgb) - TWO_SIGMA_LIGHT_SQUARE;
1028								}
1029							}
1030		
1031							patch_square_dist = max(0.0f, patch_square_dist / (3.0f * PATCH_WINDOW_DIMENSION_SQUARE));
1032		
1033							float weight = 1.0f;
1034		
1035							// Ignore weight if search position is out of bounds.
1036							weight *= step(0, search_pos.x) * step(search_pos.x, bake_params.atlas_size.x - 1);
1037							weight *= step(0, search_pos.y) * step(search_pos.y, bake_params.atlas_size.y - 1);
1038		
1039							// Ignore weight if normal is zero length.
1040							weight *= step(EPSILON, length(search_normal));
1041		
1042							// Weight with pixel distance.
1043							vec2 pixel_delta = vec2(search_x, search_y);
1044							float pixel_square_dist = dot(pixel_delta, pixel_delta);
1045							weight *= exp(-pixel_square_dist / TWO_SIGMA_SPATIAL_SQUARE);
1046		
1047							// Weight with patch.
1048							weight *= exp(-patch_square_dist / FILTER_SQUARE_TWO_SIGMA_LIGHT_SQUARE);
1049		
1050							// Weight with albedo.
1051							vec3 albedo_delta = input_albedo - search_albedo;
1052							float albedo_square_dist = dot(albedo_delta, albedo_delta);
1053							weight *= exp(-albedo_square_dist / TWO_SIGMA_ALBEDO_SQUARE);
1054		
1055							// Weight with normal.
1056							vec3 normal_delta = input_normal - search_normal;
1057							float normal_square_dist = dot(normal_delta, normal_delta);
1058							weight *= exp(-normal_square_dist / TWO_SIGMA_NORMAL_SQUARE);
1059		
1060							denoised_rgb += weight * search_rgb;
1061							sum_weights += weight;
1062						}
1063					}
1064		
1065					denoised_rgb /= sum_weights;
1066				} else {
1067					// Ignore pixels where the normal is empty, just copy the light color.
1068					denoised_rgb = input_light.rgb;
1069				}
1070		
1071				imageStore(dest_light, ivec3(atlas_pos, lightmap_slice), vec4(denoised_rgb, input_light.a));
1072			}
1073		#endif
1074		}
1075		
1076		
          RDShaderSPIRV          ­  Failed parse:
ERROR: 0:282: 'CLUSTER_SIZE' : undeclared identifier 
ERROR: 0:282: '' : compilation terminated 
ERROR: 2 compilation errors.  No code generated.




Stage 'compute' source code: 

1		
2		#version 450
3		
4		#
5		#define MODE_LIGHT_PROBES
6		
7		
8		
9		// One 2D local group focusing in one layer at a time, though all
10		// in parallel (no barriers) makes more sense than a 3D local group
11		// as this can take more advantage of the cache for each group.
12		
13		#ifdef MODE_LIGHT_PROBES
14		
15		layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
16		
17		#else
18		
19		layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
20		
21		#endif
22		
23		
24		
25		/* SET 0, static data that does not change between any call */
26		
27		layout(set = 0, binding = 0) uniform BakeParameters {
28			vec3 world_size;
29			float bias;
30		
31			vec3 to_cell_offset;
32			int grid_size;
33		
34			vec3 to_cell_size;
35			uint light_count;
36		
37			mat3x4 env_transform;
38		
39			ivec2 atlas_size;
40			float exposure_normalization;
41			uint bounces;
42		
43			float bounce_indirect_energy;
44		}
45		bake_params;
46		
47		struct Vertex {
48			vec3 position;
49			float normal_z;
50			vec2 uv;
51			vec2 normal_xy;
52		};
53		
54		layout(set = 0, binding = 1, std430) restrict readonly buffer Vertices {
55			Vertex data[];
56		}
57		vertices;
58		
59		struct Triangle {
60			uvec3 indices;
61			uint slice;
62			vec3 min_bounds;
63			uint pad0;
64			vec3 max_bounds;
65			uint pad1;
66		};
67		
68		struct ClusterAABB {
69			vec3 min_bounds;
70			uint pad0;
71			vec3 max_bounds;
72			uint pad1;
73		};
74		
75		layout(set = 0, binding = 2, std430) restrict readonly buffer Triangles {
76			Triangle data[];
77		}
78		triangles;
79		
80		layout(set = 0, binding = 3, std430) restrict readonly buffer TriangleIndices {
81			uint data[];
82		}
83		triangle_indices;
84		
85		#define LIGHT_TYPE_DIRECTIONAL 0
86		#define LIGHT_TYPE_OMNI 1
87		#define LIGHT_TYPE_SPOT 2
88		
89		struct Light {
90			vec3 position;
91			uint type;
92		
93			vec3 direction;
94			float energy;
95		
96			vec3 color;
97			float size;
98		
99			float range;
100			float attenuation;
101			float cos_spot_angle;
102			float inv_spot_attenuation;
103		
104			float indirect_energy;
105			float shadow_blur;
106			bool static_bake;
107			uint pad;
108		};
109		
110		layout(set = 0, binding = 4, std430) restrict readonly buffer Lights {
111			Light data[];
112		}
113		lights;
114		
115		struct Seam {
116			uvec2 a;
117			uvec2 b;
118		};
119		
120		layout(set = 0, binding = 5, std430) restrict readonly buffer Seams {
121			Seam data[];
122		}
123		seams;
124		
125		layout(set = 0, binding = 6, std430) restrict readonly buffer Probes {
126			vec4 data[];
127		}
128		probe_positions;
129		
130		layout(set = 0, binding = 7) uniform utexture3D grid;
131		
132		layout(set = 0, binding = 8) uniform texture2DArray albedo_tex;
133		layout(set = 0, binding = 9) uniform texture2DArray emission_tex;
134		
135		layout(set = 0, binding = 10) uniform sampler linear_sampler;
136		
137		layout(set = 0, binding = 11, std430) restrict readonly buffer ClusterIndices {
138			uint data[];
139		}
140		cluster_indices;
141		
142		layout(set = 0, binding = 12, std430) restrict readonly buffer ClusterAABBs {
143			ClusterAABB data[];
144		}
145		cluster_aabbs;
146		
147		// Fragment action constants
148		const uint FA_NONE = 0;
149		const uint FA_SMOOTHEN_POSITION = 1;
150		
151		
152		#ifdef MODE_LIGHT_PROBES
153		
154		layout(set = 1, binding = 0, std430) restrict buffer LightProbeData {
155			vec4 data[];
156		}
157		light_probes;
158		
159		layout(set = 1, binding = 1) uniform texture2DArray source_light;
160		layout(set = 1, binding = 2) uniform texture2D environment;
161		#endif
162		
163		#ifdef MODE_UNOCCLUDE
164		
165		layout(rgba32f, set = 1, binding = 0) uniform restrict image2DArray position;
166		layout(rgba32f, set = 1, binding = 1) uniform restrict readonly image2DArray unocclude;
167		
168		#endif
169		
170		#if defined(MODE_DIRECT_LIGHT) || defined(MODE_BOUNCE_LIGHT)
171		
172		layout(rgba16f, set = 1, binding = 0) uniform restrict writeonly image2DArray dest_light;
173		layout(set = 1, binding = 1) uniform texture2DArray source_light;
174		layout(set = 1, binding = 2) uniform texture2DArray source_position;
175		layout(set = 1, binding = 3) uniform texture2DArray source_normal;
176		layout(rgba16f, set = 1, binding = 4) uniform restrict image2DArray accum_light;
177		
178		#endif
179		
180		#ifdef MODE_BOUNCE_LIGHT
181		layout(set = 1, binding = 5) uniform texture2D environment;
182		#endif
183		
184		#if defined(MODE_DILATE) || defined(MODE_DENOISE)
185		layout(rgba16f, set = 1, binding = 0) uniform restrict writeonly image2DArray dest_light;
186		layout(set = 1, binding = 1) uniform texture2DArray source_light;
187		#endif
188		
189		#ifdef MODE_DENOISE
190		layout(set = 1, binding = 2) uniform texture2DArray source_normal;
191		layout(set = 1, binding = 3) uniform DenoiseParams {
192			float spatial_bandwidth;
193			float light_bandwidth;
194			float albedo_bandwidth;
195			float normal_bandwidth;
196		
197			float filter_strength;
198		}
199		denoise_params;
200		#endif
201		
202		layout(push_constant, std430) uniform Params {
203			uint atlas_slice;
204			uint ray_count;
205			uint ray_from;
206			uint ray_to;
207		
208			ivec2 region_ofs;
209			uint probe_count;
210		}
211		params;
212		
213		//check it, but also return distance and barycentric coords (for uv lookup)
214		bool ray_hits_triangle(vec3 from, vec3 dir, float max_dist, vec3 p0, vec3 p1, vec3 p2, out float r_distance, out vec3 r_barycentric) {
215			const float EPSILON = 0.00001;
216			const vec3 e0 = p1 - p0;
217			const vec3 e1 = p0 - p2;
218			vec3 triangle_normal = cross(e1, e0);
219		
220			float n_dot_dir = dot(triangle_normal, dir);
221		
222			if (abs(n_dot_dir) < EPSILON) {
223				return false;
224			}
225		
226			const vec3 e2 = (p0 - from) / n_dot_dir;
227			const vec3 i = cross(dir, e2);
228		
229			r_barycentric.y = dot(i, e1);
230			r_barycentric.z = dot(i, e0);
231			r_barycentric.x = 1.0 - (r_barycentric.z + r_barycentric.y);
232			r_distance = dot(triangle_normal, e2);
233		
234			return (r_distance > bake_params.bias) && (r_distance < max_dist) && all(greaterThanEqual(r_barycentric, vec3(0.0)));
235		}
236		
237		const uint RAY_MISS = 0;
238		const uint RAY_FRONT = 1;
239		const uint RAY_BACK = 2;
240		const uint RAY_ANY = 3;
241		
242		bool ray_box_test(vec3 p_from, vec3 p_inv_dir, vec3 p_box_min, vec3 p_box_max) {
243			vec3 t0 = (p_box_min - p_from) * p_inv_dir;
244			vec3 t1 = (p_box_max - p_from) * p_inv_dir;
245			vec3 tmin = min(t0, t1), tmax = max(t0, t1);
246			return max(tmin.x, max(tmin.y, tmin.z)) <= min(tmax.x, min(tmax.y, tmax.z));
247		}
248		
249		#if CLUSTER_SIZE > 32
250		#define CLUSTER_TRIANGLE_ITERATION
251		#endif
252		
253		uint trace_ray(vec3 p_from, vec3 p_to, bool p_any_hit, out float r_distance, out vec3 r_normal, out uint r_triangle, out vec3 r_barycentric) {
254			// World coordinates.
255			vec3 rel = p_to - p_from;
256			float rel_len = length(rel);
257			vec3 dir = normalize(rel);
258			vec3 inv_dir = 1.0 / dir;
259		
260			// Cell coordinates.
261			vec3 from_cell = (p_from - bake_params.to_cell_offset) * bake_params.to_cell_size;
262			vec3 to_cell = (p_to - bake_params.to_cell_offset) * bake_params.to_cell_size;
263		
264			// Prepare DDA.
265			vec3 rel_cell = to_cell - from_cell;
266			ivec3 icell = ivec3(from_cell);
267			ivec3 iendcell = ivec3(to_cell);
268			vec3 dir_cell = normalize(rel_cell);
269			vec3 delta = min(abs(1.0 / dir_cell), bake_params.grid_size); // Use bake_params.grid_size as max to prevent infinity values.
270			ivec3 step = ivec3(sign(rel_cell));
271			vec3 side = (sign(rel_cell) * (vec3(icell) - from_cell) + (sign(rel_cell) * 0.5) + 0.5) * delta;
272		
273			uint iters = 0;
274			while (all(greaterThanEqual(icell, ivec3(0))) && all(lessThan(icell, ivec3(bake_params.grid_size))) && (iters < 1000)) {
275				uvec2 cell_data = texelFetch(usampler3D(grid, linear_sampler), icell, 0).xy;
276				uint triangle_count = cell_data.x;
277				if (triangle_count > 0) {
278					uint hit = RAY_MISS;
279					float best_distance = 1e20;
280					uint cluster_start = cluster_indices.data[cell_data.y * 2];
281					uint cell_triangle_start = cluster_indices.data[cell_data.y * 2 + 1];
282					uint cluster_count = (triangle_count + CLUSTER_SIZE - 1) / CLUSTER_SIZE;
283					uint cluster_base_index = 0;
284					while (cluster_base_index < cluster_count) {
285						// To minimize divergence, all Ray-AABB tests on the clusters contained in the cell are performed
286						// before checking against the triangles. We do this 32 clusters at a time and store the intersected
287						// clusters on each bit of the 32-bit integer.
288						uint cluster_test_count = min(32, cluster_count - cluster_base_index);
289						uint cluster_hits = 0;
290						for (uint i = 0; i < cluster_test_count; i++) {
291							uint cluster_index = cluster_start + cluster_base_index + i;
292							ClusterAABB cluster_aabb = cluster_aabbs.data[cluster_index];
293							if (ray_box_test(p_from, inv_dir, cluster_aabb.min_bounds, cluster_aabb.max_bounds)) {
294								cluster_hits |= (1 << i);
295							}
296						}
297		
298						// Check the triangles in any of the clusters that were intersected by toggling off the bits in the
299						// 32-bit integer counter until no bits are left.
300						while (cluster_hits > 0) {
301							uint cluster_index = findLSB(cluster_hits);
302							cluster_hits &= ~(1 << cluster_index);
303							cluster_index += cluster_base_index;
304		
305							// Do the same divergence execution trick with triangles as well.
306							uint triangle_base_index = 0;
307		#ifdef CLUSTER_TRIANGLE_ITERATION
308							while (triangle_base_index < triangle_count)
309		#endif
310							{
311								uint triangle_start_index = cell_triangle_start + cluster_index * CLUSTER_SIZE + triangle_base_index;
312								uint triangle_test_count = min(CLUSTER_SIZE, triangle_count - triangle_base_index);
313								uint triangle_hits = 0;
314								for (uint i = 0; i < triangle_test_count; i++) {
315									uint triangle_index = triangle_indices.data[triangle_start_index + i];
316									if (ray_box_test(p_from, inv_dir, triangles.data[triangle_index].min_bounds, triangles.data[triangle_index].max_bounds)) {
317										triangle_hits |= (1 << i);
318									}
319								}
320		
321								while (triangle_hits > 0) {
322									uint cluster_triangle_index = findLSB(triangle_hits);
323									triangle_hits &= ~(1 << cluster_triangle_index);
324									cluster_triangle_index += triangle_start_index;
325		
326									uint triangle_index = triangle_indices.data[cluster_triangle_index];
327									Triangle triangle = triangles.data[triangle_index];
328		
329									// Gather the triangle vertex positions.
330									vec3 vtx0 = vertices.data[triangle.indices.x].position;
331									vec3 vtx1 = vertices.data[triangle.indices.y].position;
332									vec3 vtx2 = vertices.data[triangle.indices.z].position;
333									vec3 normal = -normalize(cross((vtx0 - vtx1), (vtx0 - vtx2)));
334									bool backface = dot(normal, dir) >= 0.0;
335									float distance;
336									vec3 barycentric;
337									if (ray_hits_triangle(p_from, dir, rel_len, vtx0, vtx1, vtx2, distance, barycentric)) {
338										if (p_any_hit) {
339											// Return early if any hit was requested.
340											return RAY_ANY;
341										}
342		
343										vec3 position = p_from + dir * distance;
344										vec3 hit_cell = (position - bake_params.to_cell_offset) * bake_params.to_cell_size;
345										if (icell != ivec3(hit_cell)) {
346											// It's possible for the ray to hit a triangle in a position outside the bounds of the cell
347											// if it's large enough to cover multiple ones. The hit must be ignored if this is the case.
348											continue;
349										}
350		
351										if (!backface) {
352											// The case of meshes having both a front and back face in the same plane is more common than
353											// expected, so if this is a front-face, bias it closer to the ray origin, so it always wins
354											// over the back-face.
355											distance = max(bake_params.bias, distance - bake_params.bias);
356										}
357		
358										if (distance < best_distance) {
359											hit = backface ? RAY_BACK : RAY_FRONT;
360											best_distance = distance;
361											r_distance = distance;
362											r_normal = normal;
363											r_triangle = triangle_index;
364											r_barycentric = barycentric;
365										}
366									}
367								}
368		
369		#ifdef CLUSTER_TRIANGLE_ITERATION
370								triangle_base_index += CLUSTER_SIZE;
371		#endif
372							}
373						}
374		
375						cluster_base_index += 32;
376					}
377		
378					if (hit != RAY_MISS) {
379						return hit;
380					}
381				}
382		
383				if (icell == iendcell) {
384					break;
385				}
386		
387				bvec3 mask = lessThanEqual(side.xyz, min(side.yzx, side.zxy));
388				side += vec3(mask) * delta;
389				icell += ivec3(vec3(mask)) * step;
390				iters++;
391			}
392		
393			return RAY_MISS;
394		}
395		
396		uint trace_ray_closest_hit_triangle(vec3 p_from, vec3 p_to, out uint r_triangle, out vec3 r_barycentric) {
397			float distance;
398			vec3 normal;
399			return trace_ray(p_from, p_to, false, distance, normal, r_triangle, r_barycentric);
400		}
401		
402		uint trace_ray_closest_hit_distance(vec3 p_from, vec3 p_to, out float r_distance, out vec3 r_normal) {
403			uint triangle;
404			vec3 barycentric;
405			return trace_ray(p_from, p_to, false, r_distance, r_normal, triangle, barycentric);
406		}
407		
408		uint trace_ray_any_hit(vec3 p_from, vec3 p_to) {
409			float distance;
410			vec3 normal;
411			uint triangle;
412			vec3 barycentric;
413			return trace_ray(p_from, p_to, true, distance, normal, triangle, barycentric);
414		}
415		
416		// https://www.reedbeta.com/blog/hash-functions-for-gpu-rendering/
417		uint hash(uint value) {
418			uint state = value * 747796405u + 2891336453u;
419			uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
420			return (word >> 22u) ^ word;
421		}
422		
423		uint random_seed(ivec3 seed) {
424			return hash(seed.x ^ hash(seed.y ^ hash(seed.z)));
425		}
426		
427		// generates a random value in range [0.0, 1.0)
428		float randomize(inout uint value) {
429			value = hash(value);
430			return float(value / 4294967296.0);
431		}
432		
433		const float PI = 3.14159265f;
434		
435		// http://www.realtimerendering.com/raytracinggems/unofficial_RayTracingGems_v1.4.pdf (chapter 15)
436		vec3 generate_hemisphere_cosine_weighted_direction(inout uint noise) {
437			float noise1 = randomize(noise);
438			float noise2 = randomize(noise) * 2.0 * PI;
439		
440			return vec3(sqrt(noise1) * cos(noise2), sqrt(noise1) * sin(noise2), sqrt(1.0 - noise1));
441		}
442		
443		// Distribution generation adapted from "Generating uniformly distributed numbers on a sphere"
444		// <http://corysimon.github.io/articles/uniformdistn-on-sphere/>
445		vec3 generate_sphere_uniform_direction(inout uint noise) {
446			float theta = 2.0 * PI * randomize(noise);
447			float phi = acos(1.0 - 2.0 * randomize(noise));
448			return vec3(sin(phi) * cos(theta), sin(phi) * sin(theta), cos(phi));
449		}
450		
451		vec3 generate_ray_dir_from_normal(vec3 normal, inout uint noise) {
452			vec3 v0 = abs(normal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
453			vec3 tangent = normalize(cross(v0, normal));
454			vec3 bitangent = normalize(cross(tangent, normal));
455			mat3 normal_mat = mat3(tangent, bitangent, normal);
456			return normal_mat * generate_hemisphere_cosine_weighted_direction(noise);
457		}
458		
459		#if defined(MODE_DIRECT_LIGHT) || defined(MODE_BOUNCE_LIGHT) || defined(MODE_LIGHT_PROBES)
460		
461		float get_omni_attenuation(float distance, float inv_range, float decay) {
462			float nd = distance * inv_range;
463			nd *= nd;
464			nd *= nd; // nd^4
465			nd = max(1.0 - nd, 0.0);
466			nd *= nd; // nd^2
467			return nd * pow(max(distance, 0.0001), -decay);
468		}
469		
470		void trace_direct_light(vec3 p_position, vec3 p_normal, uint p_light_index, bool p_soft_shadowing, out vec3 r_light, out vec3 r_light_dir, inout uint r_noise) {
471			r_light = vec3(0.0f);
472		
473			vec3 light_pos;
474			float dist;
475			float attenuation;
476			float soft_shadowing_disk_size;
477			Light light_data = lights.data[p_light_index];
478			if (light_data.type == LIGHT_TYPE_DIRECTIONAL) {
479				vec3 light_vec = light_data.direction;
480				light_pos = p_position - light_vec * length(bake_params.world_size);
481				r_light_dir = normalize(light_pos - p_position);
482				dist = length(bake_params.world_size);
483				attenuation = 1.0;
484				soft_shadowing_disk_size = light_data.size;
485			} else {
486				light_pos = light_data.position;
487				r_light_dir = normalize(light_pos - p_position);
488				dist = distance(p_position, light_pos);
489				if (dist > light_data.range) {
490					return;
491				}
492		
493				soft_shadowing_disk_size = light_data.size / dist;
494		
495				attenuation = get_omni_attenuation(dist, 1.0 / light_data.range, light_data.attenuation);
496		
497				if (light_data.type == LIGHT_TYPE_SPOT) {
498					vec3 rel = normalize(p_position - light_pos);
499					float cos_spot_angle = light_data.cos_spot_angle;
500					float cos_angle = dot(rel, light_data.direction);
501		
502					if (cos_angle < cos_spot_angle) {
503						return;
504					}
505		
506					float scos = max(cos_angle, cos_spot_angle);
507					float spot_rim = max(0.0001, (1.0 - scos) / (1.0 - cos_spot_angle));
508					attenuation *= 1.0 - pow(spot_rim, light_data.inv_spot_attenuation);
509				}
510			}
511		
512			attenuation *= max(0.0, dot(p_normal, r_light_dir));
513			if (attenuation <= 0.0001) {
514				return;
515			}
516		
517			float penumbra = 0.0;
518			if ((light_data.size > 0.0) && p_soft_shadowing) {
519				vec3 light_to_point = -r_light_dir;
520				vec3 aux = light_to_point.y < 0.777 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
521				vec3 light_to_point_tan = normalize(cross(light_to_point, aux));
522				vec3 light_to_point_bitan = normalize(cross(light_to_point, light_to_point_tan));
523		
524				const uint shadowing_rays_check_penumbra_denom = 2;
525				uint shadowing_ray_count = p_soft_shadowing ? params.ray_count : 1;
526		
527				uint hits = 0;
528				vec3 light_disk_to_point = light_to_point;
529				for (uint j = 0; j < shadowing_ray_count; j++) {
530					// Optimization:
531					// Once already traced an important proportion of rays, if all are hits or misses,
532					// assume we're not in the penumbra so we can infer the rest would have the same result
533					if (p_soft_shadowing) {
534						if (j == shadowing_ray_count / shadowing_rays_check_penumbra_denom) {
535							if (hits == j) {
536								// Assume totally lit
537								hits = shadowing_ray_count;
538								break;
539							} else if (hits == 0) {
540								// Assume totally dark
541								hits = 0;
542								break;
543							}
544						}
545					}
546		
547					float r = randomize(r_noise);
548					float a = randomize(r_noise) * 2.0 * PI;
549					vec2 disk_sample = (r * vec2(cos(a), sin(a))) * soft_shadowing_disk_size * light_data.shadow_blur;
550					light_disk_to_point = normalize(light_to_point + disk_sample.x * light_to_point_tan + disk_sample.y * light_to_point_bitan);
551		
552					if (trace_ray_any_hit(p_position - light_disk_to_point * bake_params.bias, p_position - light_disk_to_point * dist) == RAY_MISS) {
553						hits++;
554					}
555				}
556		
557				penumbra = float(hits) / float(shadowing_ray_count);
558			} else {
559				if (trace_ray_any_hit(p_position + r_light_dir * bake_params.bias, light_pos) == RAY_MISS) {
560					penumbra = 1.0;
561				}
562			}
563		
564			r_light = light_data.color * light_data.energy * attenuation * penumbra;
565		}
566		
567		#endif
568		
569		#if defined(MODE_BOUNCE_LIGHT) || defined(MODE_LIGHT_PROBES)
570		
571		vec3 trace_environment_color(vec3 ray_dir) {
572			vec3 sky_dir = normalize(mat3(bake_params.env_transform) * ray_dir);
573			vec2 st = vec2(atan(sky_dir.x, sky_dir.z), acos(sky_dir.y));
574			if (st.x < 0.0) {
575				st.x += PI * 2.0;
576			}
577		
578			return textureLod(sampler2D(environment, linear_sampler), st / vec2(PI * 2.0, PI), 0.0).rgb;
579		}
580		
581		vec3 trace_indirect_light(vec3 p_position, vec3 p_ray_dir, inout uint r_noise) {
582			// The lower limit considers the case where the lightmapper might have bounces disabled but light probes are requested.
583			vec3 position = p_position;
584			vec3 ray_dir = p_ray_dir;
585			uint max_depth = max(bake_params.bounces, 1);
586			vec3 throughput = vec3(1.0);
587			vec3 light = vec3(0.0);
588			for (uint depth = 0; depth < max_depth; depth++) {
589				uint tidx;
590				vec3 barycentric;
591				uint trace_result = trace_ray_closest_hit_triangle(position + ray_dir * bake_params.bias, position + ray_dir * length(bake_params.world_size), tidx, barycentric);
592				if (trace_result == RAY_FRONT) {
593					Vertex vert0 = vertices.data[triangles.data[tidx].indices.x];
594					Vertex vert1 = vertices.data[triangles.data[tidx].indices.y];
595					Vertex vert2 = vertices.data[triangles.data[tidx].indices.z];
596					vec3 uvw = vec3(barycentric.x * vert0.uv + barycentric.y * vert1.uv + barycentric.z * vert2.uv, float(triangles.data[tidx].slice));
597					position = barycentric.x * vert0.position + barycentric.y * vert1.position + barycentric.z * vert2.position;
598		
599					vec3 norm0 = vec3(vert0.normal_xy, vert0.normal_z);
600					vec3 norm1 = vec3(vert1.normal_xy, vert1.normal_z);
601					vec3 norm2 = vec3(vert2.normal_xy, vert2.normal_z);
602					vec3 normal = barycentric.x * norm0 + barycentric.y * norm1 + barycentric.z * norm2;
603		
604					vec3 direct_light = vec3(0.0f);
605		#ifdef USE_LIGHT_TEXTURE_FOR_BOUNCES
606					direct_light += textureLod(sampler2DArray(source_light, linear_sampler), uvw, 0.0).rgb;
607		#else
608					// Trace the lights directly. Significantly more expensive but more accurate in scenarios
609					// where the lightmap texture isn't reliable.
610					for (uint i = 0; i < bake_params.light_count; i++) {
611						vec3 light;
612						vec3 light_dir;
613						trace_direct_light(position, normal, i, false, light, light_dir, r_noise);
614						direct_light += light * lights.data[i].indirect_energy;
615					}
616		
617					direct_light *= bake_params.exposure_normalization;
618		#endif
619		
620					vec3 albedo = textureLod(sampler2DArray(albedo_tex, linear_sampler), uvw, 0).rgb;
621					vec3 emissive = textureLod(sampler2DArray(emission_tex, linear_sampler), uvw, 0).rgb;
622					emissive *= bake_params.exposure_normalization;
623		
624					light += throughput * emissive;
625					throughput *= albedo;
626					light += throughput * direct_light * bake_params.bounce_indirect_energy;
627		
628					// Use Russian Roulette to determine a probability to terminate the bounce earlier as an optimization.
629					// <https://computergraphics.stackexchange.com/questions/2316/is-russian-roulette-really-the-answer>
630					float p = max(max(throughput.x, throughput.y), throughput.z);
631					if (randomize(r_noise) > p) {
632						break;
633					}
634		
635					// Boost the throughput from the probability of the ray being terminated early.
636					throughput *= 1.0 / p;
637		
638					// Generate a new ray direction for the next bounce from this surface's normal.
639					ray_dir = generate_ray_dir_from_normal(normal, r_noise);
640				} else if (trace_result == RAY_MISS) {
641					// Look for the environment color and stop bouncing.
642					light += throughput * trace_environment_color(ray_dir);
643					break;
644				} else {
645					// Ignore any other trace results.
646					break;
647				}
648			}
649		
650			return light;
651		}
652		
653		#endif
654		
655		void main() {
656			// Check if invocation is out of bounds.
657		#ifdef MODE_LIGHT_PROBES
658			int probe_index = int(gl_GlobalInvocationID.x);
659			if (probe_index >= params.probe_count) {
660				return;
661			}
662		
663		#else
664			ivec2 atlas_pos = ivec2(gl_GlobalInvocationID.xy) + params.region_ofs;
665			if (any(greaterThanEqual(atlas_pos, bake_params.atlas_size))) {
666				return;
667			}
668		#endif
669		
670		#ifdef MODE_DIRECT_LIGHT
671		
672			vec3 normal = texelFetch(sampler2DArray(source_normal, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).xyz;
673			if (length(normal) < 0.5) {
674				return; //empty texel, no process
675			}
676			vec3 position = texelFetch(sampler2DArray(source_position, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).xyz;
677			vec3 light_for_texture = vec3(0.0);
678			vec3 light_for_bounces = vec3(0.0);
679		
680		#ifdef USE_SH_LIGHTMAPS
681			vec4 sh_accum[4] = vec4[](
682					vec4(0.0, 0.0, 0.0, 1.0),
683					vec4(0.0, 0.0, 0.0, 1.0),
684					vec4(0.0, 0.0, 0.0, 1.0),
685					vec4(0.0, 0.0, 0.0, 1.0));
686		#endif
687		
688			// Use atlas position and a prime number as the seed.
689			uint noise = random_seed(ivec3(atlas_pos, 43573547));
690			for (uint i = 0; i < bake_params.light_count; i++) {
691				vec3 light;
692				vec3 light_dir;
693				trace_direct_light(position, normal, i, true, light, light_dir, noise);
694		
695				if (lights.data[i].static_bake) {
696					light_for_texture += light;
697		
698		#ifdef USE_SH_LIGHTMAPS
699					float c[4] = float[](
700							0.282095, //l0
701							0.488603 * light_dir.y, //l1n1
702							0.488603 * light_dir.z, //l1n0
703							0.488603 * light_dir.x //l1p1
704					);
705		
706					for (uint j = 0; j < 4; j++) {
707						sh_accum[j].rgb += light * c[j] * 8.0;
708					}
709		#endif
710				}
711		
712				light_for_bounces += light * lights.data[i].indirect_energy;
713			}
714		
715			light_for_bounces *= bake_params.exposure_normalization;
716			imageStore(dest_light, ivec3(atlas_pos, params.atlas_slice), vec4(light_for_bounces, 1.0));
717		
718		#ifdef USE_SH_LIGHTMAPS
719			// Keep for adding at the end.
720			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + 0), sh_accum[0]);
721			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + 1), sh_accum[1]);
722			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + 2), sh_accum[2]);
723			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + 3), sh_accum[3]);
724		#else
725			light_for_texture *= bake_params.exposure_normalization;
726			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice), vec4(light_for_texture, 1.0));
727		#endif
728		
729		#endif
730		
731		#ifdef MODE_BOUNCE_LIGHT
732		
733		#ifdef USE_SH_LIGHTMAPS
734			vec4 sh_accum[4] = vec4[](
735					vec4(0.0, 0.0, 0.0, 1.0),
736					vec4(0.0, 0.0, 0.0, 1.0),
737					vec4(0.0, 0.0, 0.0, 1.0),
738					vec4(0.0, 0.0, 0.0, 1.0));
739		#else
740			vec3 light_accum = vec3(0.0);
741		#endif
742		
743			// Retrieve starting normal and position.
744			vec3 normal = texelFetch(sampler2DArray(source_normal, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).xyz;
745			if (length(normal) < 0.5) {
746				// The pixel is empty, skip processing it.
747				return;
748			}
749		
750			vec3 position = texelFetch(sampler2DArray(source_position, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).xyz;
751			uint noise = random_seed(ivec3(params.ray_from, atlas_pos));
752			for (uint i = params.ray_from; i < params.ray_to; i++) {
753				vec3 ray_dir = generate_ray_dir_from_normal(normal, noise);
754				vec3 light = trace_indirect_light(position, ray_dir, noise);
755		
756		#ifdef USE_SH_LIGHTMAPS
757				float c[4] = float[](
758						0.282095, //l0
759						0.488603 * ray_dir.y, //l1n1
760						0.488603 * ray_dir.z, //l1n0
761						0.488603 * ray_dir.x //l1p1
762				);
763		
764				for (uint j = 0; j < 4; j++) {
765					sh_accum[j].rgb += light * c[j] * 8.0;
766				}
767		#else
768				light_accum += light;
769		#endif
770			}
771		
772			// Add the averaged result to the accumulated light texture.
773		#ifdef USE_SH_LIGHTMAPS
774			for (int i = 0; i < 4; i++) {
775				vec4 accum = imageLoad(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + i));
776				accum.rgb += sh_accum[i].rgb / float(params.ray_count);
777				imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + i), accum);
778			}
779		#else
780			vec4 accum = imageLoad(accum_light, ivec3(atlas_pos, params.atlas_slice));
781			accum.rgb += light_accum / float(params.ray_count);
782			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice), accum);
783		#endif
784		
785		#endif
786		
787		#ifdef MODE_UNOCCLUDE
788		
789			//texel_size = 0.5;
790			//compute tangents
791		
792			vec4 position_alpha = imageLoad(position, ivec3(atlas_pos, params.atlas_slice));
793			if (position_alpha.a < 0.5) {
794				return;
795			}
796		
797			vec3 vertex_pos = position_alpha.xyz;
798			vec4 normal_tsize = imageLoad(unocclude, ivec3(atlas_pos, params.atlas_slice));
799		
800			vec3 face_normal = normal_tsize.xyz;
801			float texel_size = normal_tsize.w;
802		
803			vec3 v0 = abs(face_normal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
804			vec3 tangent = normalize(cross(v0, face_normal));
805			vec3 bitangent = normalize(cross(tangent, face_normal));
806			vec3 base_pos = vertex_pos + face_normal * bake_params.bias; // Raise a bit.
807		
808			vec3 rays[4] = vec3[](tangent, bitangent, -tangent, -bitangent);
809			float min_d = 1e20;
810			for (int i = 0; i < 4; i++) {
811				vec3 ray_to = base_pos + rays[i] * texel_size;
812				float d;
813				vec3 norm;
814		
815				if (trace_ray_closest_hit_distance(base_pos, ray_to, d, norm) == RAY_BACK) {
816					if (d < min_d) {
817						// This bias needs to be greater than the regular bias, because otherwise later, rays will go the other side when pointing back.
818						vertex_pos = base_pos + rays[i] * d + norm * bake_params.bias * 10.0;
819						min_d = d;
820					}
821				}
822			}
823		
824			position_alpha.xyz = vertex_pos;
825		
826			imageStore(position, ivec3(atlas_pos, params.atlas_slice), position_alpha);
827		
828		#endif
829		
830		#ifdef MODE_LIGHT_PROBES
831		
832			vec3 position = probe_positions.data[probe_index].xyz;
833		
834			vec4 probe_sh_accum[9] = vec4[](
835					vec4(0.0),
836					vec4(0.0),
837					vec4(0.0),
838					vec4(0.0),
839					vec4(0.0),
840					vec4(0.0),
841					vec4(0.0),
842					vec4(0.0),
843					vec4(0.0));
844		
845			uint noise = random_seed(ivec3(params.ray_from, probe_index, 49502741 /* some prime */));
846			for (uint i = params.ray_from; i < params.ray_to; i++) {
847				vec3 ray_dir = generate_sphere_uniform_direction(noise);
848				vec3 light = trace_indirect_light(position, ray_dir, noise);
849		
850				float c[9] = float[](
851						0.282095, //l0
852						0.488603 * ray_dir.y, //l1n1
853						0.488603 * ray_dir.z, //l1n0
854						0.488603 * ray_dir.x, //l1p1
855						1.092548 * ray_dir.x * ray_dir.y, //l2n2
856						1.092548 * ray_dir.y * ray_dir.z, //l2n1
857						//0.315392 * (ray_dir.x * ray_dir.x + ray_dir.y * ray_dir.y + 2.0 * ray_dir.z * ray_dir.z), //l20
858						0.315392 * (3.0 * ray_dir.z * ray_dir.z - 1.0), //l20
859						1.092548 * ray_dir.x * ray_dir.z, //l2p1
860						0.546274 * (ray_dir.x * ray_dir.x - ray_dir.y * ray_dir.y) //l2p2
861				);
862		
863				for (uint j = 0; j < 9; j++) {
864					probe_sh_accum[j].rgb += light * c[j];
865				}
866			}
867		
868			if (params.ray_from > 0) {
869				for (uint j = 0; j < 9; j++) { //accum from existing
870					probe_sh_accum[j] += light_probes.data[probe_index * 9 + j];
871				}
872			}
873		
874			if (params.ray_to == params.ray_count) {
875				for (uint j = 0; j < 9; j++) { //accum from existing
876					probe_sh_accum[j] *= 4.0 / float(params.ray_count);
877				}
878			}
879		
880			for (uint j = 0; j < 9; j++) { //accum from existing
881				light_probes.data[probe_index * 9 + j] = probe_sh_accum[j];
882			}
883		
884		#endif
885		
886		#ifdef MODE_DILATE
887		
888			vec4 c = texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0);
889			//sides first, as they are closer
890			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-1, 0), params.atlas_slice), 0);
891			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(0, 1), params.atlas_slice), 0);
892			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(1, 0), params.atlas_slice), 0);
893			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(0, -1), params.atlas_slice), 0);
894			//endpoints second
895			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-1, -1), params.atlas_slice), 0);
896			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-1, 1), params.atlas_slice), 0);
897			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(1, -1), params.atlas_slice), 0);
898			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(1, 1), params.atlas_slice), 0);
899		
900			//far sides third
901			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-2, 0), params.atlas_slice), 0);
902			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(0, 2), params.atlas_slice), 0);
903			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(2, 0), params.atlas_slice), 0);
904			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(0, -2), params.atlas_slice), 0);
905		
906			//far-mid endpoints
907			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-2, -1), params.atlas_slice), 0);
908			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-2, 1), params.atlas_slice), 0);
909			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(2, -1), params.atlas_slice), 0);
910			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(2, 1), params.atlas_slice), 0);
911		
912			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-1, -2), params.atlas_slice), 0);
913			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-1, 2), params.atlas_slice), 0);
914			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(1, -2), params.atlas_slice), 0);
915			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(1, 2), params.atlas_slice), 0);
916			//far endpoints
917			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-2, -2), params.atlas_slice), 0);
918			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-2, 2), params.atlas_slice), 0);
919			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(2, -2), params.atlas_slice), 0);
920			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(2, 2), params.atlas_slice), 0);
921		
922			imageStore(dest_light, ivec3(atlas_pos, params.atlas_slice), c);
923		
924		#endif
925		
926		#ifdef MODE_DENOISE
927			// Joint Non-local means (JNLM) denoiser.
928			//
929			// Based on YoctoImageDenoiser's JNLM implementation with corrections from "Nonlinearly Weighted First-order Regression for Denoising Monte Carlo Renderings".
930			//
931			// <https://github.com/ManuelPrandini/YoctoImageDenoiser/blob/06e19489dd64e47792acffde536393802ba48607/libs/yocto_extension/yocto_extension.cpp#L207>
932			// <https://benedikt-bitterli.me/nfor/nfor.pdf>
933			//
934			// MIT License
935			//
936			// Copyright (c) 2020 ManuelPrandini
937			//
938			// Permission is hereby granted, free of charge, to any person obtaining a copy
939			// of this software and associated documentation files (the "Software"), to deal
940			// in the Software without restriction, including without limitation the rights
941			// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
942			// copies of the Software, and to permit persons to whom the Software is
943			// furnished to do so, subject to the following conditions:
944			//
945			// The above copyright notice and this permission notice shall be included in all
946			// copies or substantial portions of the Software.
947			//
948			// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
949			// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
950			// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
951			// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
952			// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
953			// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
954			// SOFTWARE.
955			//
956			// Most of the constants below have been hand-picked to fit the common scenarios lightmaps
957			// are generated with, but they can be altered freely to experiment and achieve better results.
958		
959			// Half the size of the patch window around each pixel that is weighted to compute the denoised pixel.
960			// A value of 1 represents a 3x3 window, a value of 2 a 5x5 window, etc.
961			const int HALF_PATCH_WINDOW = 4;
962		
963			// Half the size of the search window around each pixel that is denoised and weighted to compute the denoised pixel.
964			const int HALF_SEARCH_WINDOW = 10;
965		
966			// For all of the following sigma values, smaller values will give less weight to pixels that have a bigger distance
967			// in the feature being evaluated. Therefore, smaller values are likely to cause more noise to appear, but will also
968			// cause less features to be erased in the process.
969		
970			// Controls how much the spatial distance of the pixels influences the denoising weight.
971			const float SIGMA_SPATIAL = denoise_params.spatial_bandwidth;
972		
973			// Controls how much the light color distance of the pixels influences the denoising weight.
974			const float SIGMA_LIGHT = denoise_params.light_bandwidth;
975		
976			// Controls how much the albedo color distance of the pixels influences the denoising weight.
977			const float SIGMA_ALBEDO = denoise_params.albedo_bandwidth;
978		
979			// Controls how much the normal vector distance of the pixels influences the denoising weight.
980			const float SIGMA_NORMAL = denoise_params.normal_bandwidth;
981		
982			// Strength of the filter. The original paper recommends values around 10 to 15 times the Sigma parameter.
983			const float FILTER_VALUE = denoise_params.filter_strength * SIGMA_LIGHT;
984		
985			// Formula constants.
986			const int PATCH_WINDOW_DIMENSION = (HALF_PATCH_WINDOW * 2 + 1);
987			const int PATCH_WINDOW_DIMENSION_SQUARE = (PATCH_WINDOW_DIMENSION * PATCH_WINDOW_DIMENSION);
988			const float TWO_SIGMA_SPATIAL_SQUARE = 2.0f * SIGMA_SPATIAL * SIGMA_SPATIAL;
989			const float TWO_SIGMA_LIGHT_SQUARE = 2.0f * SIGMA_LIGHT * SIGMA_LIGHT;
990			const float TWO_SIGMA_ALBEDO_SQUARE = 2.0f * SIGMA_ALBEDO * SIGMA_ALBEDO;
991			const float TWO_SIGMA_NORMAL_SQUARE = 2.0f * SIGMA_NORMAL * SIGMA_NORMAL;
992			const float FILTER_SQUARE_TWO_SIGMA_LIGHT_SQUARE = FILTER_VALUE * FILTER_VALUE * TWO_SIGMA_LIGHT_SQUARE;
993			const float EPSILON = 1e-6f;
994		
995		#ifdef USE_SH_LIGHTMAPS
996			const uint slice_count = 4;
997			const uint slice_base = params.atlas_slice * slice_count;
998		#else
999			const uint slice_count = 1;
1000			const uint slice_base = params.atlas_slice;
1001		#endif
1002		
1003			for (uint i = 0; i < slice_count; i++) {
1004				uint lightmap_slice = slice_base + i;
1005				vec3 denoised_rgb = vec3(0.0f);
1006				vec4 input_light = texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos, lightmap_slice), 0);
1007				vec3 input_albedo = texelFetch(sampler2DArray(albedo_tex, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).rgb;
1008				vec3 input_normal = texelFetch(sampler2DArray(source_normal, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).xyz;
1009				if (length(input_normal) > EPSILON) {
1010					// Compute the denoised pixel if the normal is valid.
1011					float sum_weights = 0.0f;
1012					vec3 input_rgb = input_light.rgb;
1013					for (int search_y = -HALF_SEARCH_WINDOW; search_y <= HALF_SEARCH_WINDOW; search_y++) {
1014						for (int search_x = -HALF_SEARCH_WINDOW; search_x <= HALF_SEARCH_WINDOW; search_x++) {
1015							ivec2 search_pos = atlas_pos + ivec2(search_x, search_y);
1016							vec3 search_rgb = texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(search_pos, lightmap_slice), 0).rgb;
1017							vec3 search_albedo = texelFetch(sampler2DArray(albedo_tex, linear_sampler), ivec3(search_pos, params.atlas_slice), 0).rgb;
1018							vec3 search_normal = texelFetch(sampler2DArray(source_normal, linear_sampler), ivec3(search_pos, params.atlas_slice), 0).xyz;
1019							float patch_square_dist = 0.0f;
1020							for (int offset_y = -HALF_PATCH_WINDOW; offset_y <= HALF_PATCH_WINDOW; offset_y++) {
1021								for (int offset_x = -HALF_PATCH_WINDOW; offset_x <= HALF_PATCH_WINDOW; offset_x++) {
1022									ivec2 offset_input_pos = atlas_pos + ivec2(offset_x, offset_y);
1023									ivec2 offset_search_pos = search_pos + ivec2(offset_x, offset_y);
1024									vec3 offset_input_rgb = texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(offset_input_pos, lightmap_slice), 0).rgb;
1025									vec3 offset_search_rgb = texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(offset_search_pos, lightmap_slice), 0).rgb;
1026									vec3 offset_delta_rgb = offset_input_rgb - offset_search_rgb;
1027									patch_square_dist += dot(offset_delta_rgb, offset_delta_rgb) - TWO_SIGMA_LIGHT_SQUARE;
1028								}
1029							}
1030		
1031							patch_square_dist = max(0.0f, patch_square_dist / (3.0f * PATCH_WINDOW_DIMENSION_SQUARE));
1032		
1033							float weight = 1.0f;
1034		
1035							// Ignore weight if search position is out of bounds.
1036							weight *= step(0, search_pos.x) * step(search_pos.x, bake_params.atlas_size.x - 1);
1037							weight *= step(0, search_pos.y) * step(search_pos.y, bake_params.atlas_size.y - 1);
1038		
1039							// Ignore weight if normal is zero length.
1040							weight *= step(EPSILON, length(search_normal));
1041		
1042							// Weight with pixel distance.
1043							vec2 pixel_delta = vec2(search_x, search_y);
1044							float pixel_square_dist = dot(pixel_delta, pixel_delta);
1045							weight *= exp(-pixel_square_dist / TWO_SIGMA_SPATIAL_SQUARE);
1046		
1047							// Weight with patch.
1048							weight *= exp(-patch_square_dist / FILTER_SQUARE_TWO_SIGMA_LIGHT_SQUARE);
1049		
1050							// Weight with albedo.
1051							vec3 albedo_delta = input_albedo - search_albedo;
1052							float albedo_square_dist = dot(albedo_delta, albedo_delta);
1053							weight *= exp(-albedo_square_dist / TWO_SIGMA_ALBEDO_SQUARE);
1054		
1055							// Weight with normal.
1056							vec3 normal_delta = input_normal - search_normal;
1057							float normal_square_dist = dot(normal_delta, normal_delta);
1058							weight *= exp(-normal_square_dist / TWO_SIGMA_NORMAL_SQUARE);
1059		
1060							denoised_rgb += weight * search_rgb;
1061							sum_weights += weight;
1062						}
1063					}
1064		
1065					denoised_rgb /= sum_weights;
1066				} else {
1067					// Ignore pixels where the normal is empty, just copy the light color.
1068					denoised_rgb = input_light.rgb;
1069				}
1070		
1071				imageStore(dest_light, ivec3(atlas_pos, lightmap_slice), vec4(denoised_rgb, input_light.a));
1072			}
1073		#endif
1074		}
1075		
1076		
          RDShaderSPIRV          ­  Failed parse:
ERROR: 0:282: 'CLUSTER_SIZE' : undeclared identifier 
ERROR: 0:282: '' : compilation terminated 
ERROR: 2 compilation errors.  No code generated.




Stage 'compute' source code: 

1		
2		#version 450
3		
4		#
5		#define MODE_DIRECT_LIGHT
6		
7		
8		
9		// One 2D local group focusing in one layer at a time, though all
10		// in parallel (no barriers) makes more sense than a 3D local group
11		// as this can take more advantage of the cache for each group.
12		
13		#ifdef MODE_LIGHT_PROBES
14		
15		layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
16		
17		#else
18		
19		layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
20		
21		#endif
22		
23		
24		
25		/* SET 0, static data that does not change between any call */
26		
27		layout(set = 0, binding = 0) uniform BakeParameters {
28			vec3 world_size;
29			float bias;
30		
31			vec3 to_cell_offset;
32			int grid_size;
33		
34			vec3 to_cell_size;
35			uint light_count;
36		
37			mat3x4 env_transform;
38		
39			ivec2 atlas_size;
40			float exposure_normalization;
41			uint bounces;
42		
43			float bounce_indirect_energy;
44		}
45		bake_params;
46		
47		struct Vertex {
48			vec3 position;
49			float normal_z;
50			vec2 uv;
51			vec2 normal_xy;
52		};
53		
54		layout(set = 0, binding = 1, std430) restrict readonly buffer Vertices {
55			Vertex data[];
56		}
57		vertices;
58		
59		struct Triangle {
60			uvec3 indices;
61			uint slice;
62			vec3 min_bounds;
63			uint pad0;
64			vec3 max_bounds;
65			uint pad1;
66		};
67		
68		struct ClusterAABB {
69			vec3 min_bounds;
70			uint pad0;
71			vec3 max_bounds;
72			uint pad1;
73		};
74		
75		layout(set = 0, binding = 2, std430) restrict readonly buffer Triangles {
76			Triangle data[];
77		}
78		triangles;
79		
80		layout(set = 0, binding = 3, std430) restrict readonly buffer TriangleIndices {
81			uint data[];
82		}
83		triangle_indices;
84		
85		#define LIGHT_TYPE_DIRECTIONAL 0
86		#define LIGHT_TYPE_OMNI 1
87		#define LIGHT_TYPE_SPOT 2
88		
89		struct Light {
90			vec3 position;
91			uint type;
92		
93			vec3 direction;
94			float energy;
95		
96			vec3 color;
97			float size;
98		
99			float range;
100			float attenuation;
101			float cos_spot_angle;
102			float inv_spot_attenuation;
103		
104			float indirect_energy;
105			float shadow_blur;
106			bool static_bake;
107			uint pad;
108		};
109		
110		layout(set = 0, binding = 4, std430) restrict readonly buffer Lights {
111			Light data[];
112		}
113		lights;
114		
115		struct Seam {
116			uvec2 a;
117			uvec2 b;
118		};
119		
120		layout(set = 0, binding = 5, std430) restrict readonly buffer Seams {
121			Seam data[];
122		}
123		seams;
124		
125		layout(set = 0, binding = 6, std430) restrict readonly buffer Probes {
126			vec4 data[];
127		}
128		probe_positions;
129		
130		layout(set = 0, binding = 7) uniform utexture3D grid;
131		
132		layout(set = 0, binding = 8) uniform texture2DArray albedo_tex;
133		layout(set = 0, binding = 9) uniform texture2DArray emission_tex;
134		
135		layout(set = 0, binding = 10) uniform sampler linear_sampler;
136		
137		layout(set = 0, binding = 11, std430) restrict readonly buffer ClusterIndices {
138			uint data[];
139		}
140		cluster_indices;
141		
142		layout(set = 0, binding = 12, std430) restrict readonly buffer ClusterAABBs {
143			ClusterAABB data[];
144		}
145		cluster_aabbs;
146		
147		// Fragment action constants
148		const uint FA_NONE = 0;
149		const uint FA_SMOOTHEN_POSITION = 1;
150		
151		
152		#ifdef MODE_LIGHT_PROBES
153		
154		layout(set = 1, binding = 0, std430) restrict buffer LightProbeData {
155			vec4 data[];
156		}
157		light_probes;
158		
159		layout(set = 1, binding = 1) uniform texture2DArray source_light;
160		layout(set = 1, binding = 2) uniform texture2D environment;
161		#endif
162		
163		#ifdef MODE_UNOCCLUDE
164		
165		layout(rgba32f, set = 1, binding = 0) uniform restrict image2DArray position;
166		layout(rgba32f, set = 1, binding = 1) uniform restrict readonly image2DArray unocclude;
167		
168		#endif
169		
170		#if defined(MODE_DIRECT_LIGHT) || defined(MODE_BOUNCE_LIGHT)
171		
172		layout(rgba16f, set = 1, binding = 0) uniform restrict writeonly image2DArray dest_light;
173		layout(set = 1, binding = 1) uniform texture2DArray source_light;
174		layout(set = 1, binding = 2) uniform texture2DArray source_position;
175		layout(set = 1, binding = 3) uniform texture2DArray source_normal;
176		layout(rgba16f, set = 1, binding = 4) uniform restrict image2DArray accum_light;
177		
178		#endif
179		
180		#ifdef MODE_BOUNCE_LIGHT
181		layout(set = 1, binding = 5) uniform texture2D environment;
182		#endif
183		
184		#if defined(MODE_DILATE) || defined(MODE_DENOISE)
185		layout(rgba16f, set = 1, binding = 0) uniform restrict writeonly image2DArray dest_light;
186		layout(set = 1, binding = 1) uniform texture2DArray source_light;
187		#endif
188		
189		#ifdef MODE_DENOISE
190		layout(set = 1, binding = 2) uniform texture2DArray source_normal;
191		layout(set = 1, binding = 3) uniform DenoiseParams {
192			float spatial_bandwidth;
193			float light_bandwidth;
194			float albedo_bandwidth;
195			float normal_bandwidth;
196		
197			float filter_strength;
198		}
199		denoise_params;
200		#endif
201		
202		layout(push_constant, std430) uniform Params {
203			uint atlas_slice;
204			uint ray_count;
205			uint ray_from;
206			uint ray_to;
207		
208			ivec2 region_ofs;
209			uint probe_count;
210		}
211		params;
212		
213		//check it, but also return distance and barycentric coords (for uv lookup)
214		bool ray_hits_triangle(vec3 from, vec3 dir, float max_dist, vec3 p0, vec3 p1, vec3 p2, out float r_distance, out vec3 r_barycentric) {
215			const float EPSILON = 0.00001;
216			const vec3 e0 = p1 - p0;
217			const vec3 e1 = p0 - p2;
218			vec3 triangle_normal = cross(e1, e0);
219		
220			float n_dot_dir = dot(triangle_normal, dir);
221		
222			if (abs(n_dot_dir) < EPSILON) {
223				return false;
224			}
225		
226			const vec3 e2 = (p0 - from) / n_dot_dir;
227			const vec3 i = cross(dir, e2);
228		
229			r_barycentric.y = dot(i, e1);
230			r_barycentric.z = dot(i, e0);
231			r_barycentric.x = 1.0 - (r_barycentric.z + r_barycentric.y);
232			r_distance = dot(triangle_normal, e2);
233		
234			return (r_distance > bake_params.bias) && (r_distance < max_dist) && all(greaterThanEqual(r_barycentric, vec3(0.0)));
235		}
236		
237		const uint RAY_MISS = 0;
238		const uint RAY_FRONT = 1;
239		const uint RAY_BACK = 2;
240		const uint RAY_ANY = 3;
241		
242		bool ray_box_test(vec3 p_from, vec3 p_inv_dir, vec3 p_box_min, vec3 p_box_max) {
243			vec3 t0 = (p_box_min - p_from) * p_inv_dir;
244			vec3 t1 = (p_box_max - p_from) * p_inv_dir;
245			vec3 tmin = min(t0, t1), tmax = max(t0, t1);
246			return max(tmin.x, max(tmin.y, tmin.z)) <= min(tmax.x, min(tmax.y, tmax.z));
247		}
248		
249		#if CLUSTER_SIZE > 32
250		#define CLUSTER_TRIANGLE_ITERATION
251		#endif
252		
253		uint trace_ray(vec3 p_from, vec3 p_to, bool p_any_hit, out float r_distance, out vec3 r_normal, out uint r_triangle, out vec3 r_barycentric) {
254			// World coordinates.
255			vec3 rel = p_to - p_from;
256			float rel_len = length(rel);
257			vec3 dir = normalize(rel);
258			vec3 inv_dir = 1.0 / dir;
259		
260			// Cell coordinates.
261			vec3 from_cell = (p_from - bake_params.to_cell_offset) * bake_params.to_cell_size;
262			vec3 to_cell = (p_to - bake_params.to_cell_offset) * bake_params.to_cell_size;
263		
264			// Prepare DDA.
265			vec3 rel_cell = to_cell - from_cell;
266			ivec3 icell = ivec3(from_cell);
267			ivec3 iendcell = ivec3(to_cell);
268			vec3 dir_cell = normalize(rel_cell);
269			vec3 delta = min(abs(1.0 / dir_cell), bake_params.grid_size); // Use bake_params.grid_size as max to prevent infinity values.
270			ivec3 step = ivec3(sign(rel_cell));
271			vec3 side = (sign(rel_cell) * (vec3(icell) - from_cell) + (sign(rel_cell) * 0.5) + 0.5) * delta;
272		
273			uint iters = 0;
274			while (all(greaterThanEqual(icell, ivec3(0))) && all(lessThan(icell, ivec3(bake_params.grid_size))) && (iters < 1000)) {
275				uvec2 cell_data = texelFetch(usampler3D(grid, linear_sampler), icell, 0).xy;
276				uint triangle_count = cell_data.x;
277				if (triangle_count > 0) {
278					uint hit = RAY_MISS;
279					float best_distance = 1e20;
280					uint cluster_start = cluster_indices.data[cell_data.y * 2];
281					uint cell_triangle_start = cluster_indices.data[cell_data.y * 2 + 1];
282					uint cluster_count = (triangle_count + CLUSTER_SIZE - 1) / CLUSTER_SIZE;
283					uint cluster_base_index = 0;
284					while (cluster_base_index < cluster_count) {
285						// To minimize divergence, all Ray-AABB tests on the clusters contained in the cell are performed
286						// before checking against the triangles. We do this 32 clusters at a time and store the intersected
287						// clusters on each bit of the 32-bit integer.
288						uint cluster_test_count = min(32, cluster_count - cluster_base_index);
289						uint cluster_hits = 0;
290						for (uint i = 0; i < cluster_test_count; i++) {
291							uint cluster_index = cluster_start + cluster_base_index + i;
292							ClusterAABB cluster_aabb = cluster_aabbs.data[cluster_index];
293							if (ray_box_test(p_from, inv_dir, cluster_aabb.min_bounds, cluster_aabb.max_bounds)) {
294								cluster_hits |= (1 << i);
295							}
296						}
297		
298						// Check the triangles in any of the clusters that were intersected by toggling off the bits in the
299						// 32-bit integer counter until no bits are left.
300						while (cluster_hits > 0) {
301							uint cluster_index = findLSB(cluster_hits);
302							cluster_hits &= ~(1 << cluster_index);
303							cluster_index += cluster_base_index;
304		
305							// Do the same divergence execution trick with triangles as well.
306							uint triangle_base_index = 0;
307		#ifdef CLUSTER_TRIANGLE_ITERATION
308							while (triangle_base_index < triangle_count)
309		#endif
310							{
311								uint triangle_start_index = cell_triangle_start + cluster_index * CLUSTER_SIZE + triangle_base_index;
312								uint triangle_test_count = min(CLUSTER_SIZE, triangle_count - triangle_base_index);
313								uint triangle_hits = 0;
314								for (uint i = 0; i < triangle_test_count; i++) {
315									uint triangle_index = triangle_indices.data[triangle_start_index + i];
316									if (ray_box_test(p_from, inv_dir, triangles.data[triangle_index].min_bounds, triangles.data[triangle_index].max_bounds)) {
317										triangle_hits |= (1 << i);
318									}
319								}
320		
321								while (triangle_hits > 0) {
322									uint cluster_triangle_index = findLSB(triangle_hits);
323									triangle_hits &= ~(1 << cluster_triangle_index);
324									cluster_triangle_index += triangle_start_index;
325		
326									uint triangle_index = triangle_indices.data[cluster_triangle_index];
327									Triangle triangle = triangles.data[triangle_index];
328		
329									// Gather the triangle vertex positions.
330									vec3 vtx0 = vertices.data[triangle.indices.x].position;
331									vec3 vtx1 = vertices.data[triangle.indices.y].position;
332									vec3 vtx2 = vertices.data[triangle.indices.z].position;
333									vec3 normal = -normalize(cross((vtx0 - vtx1), (vtx0 - vtx2)));
334									bool backface = dot(normal, dir) >= 0.0;
335									float distance;
336									vec3 barycentric;
337									if (ray_hits_triangle(p_from, dir, rel_len, vtx0, vtx1, vtx2, distance, barycentric)) {
338										if (p_any_hit) {
339											// Return early if any hit was requested.
340											return RAY_ANY;
341										}
342		
343										vec3 position = p_from + dir * distance;
344										vec3 hit_cell = (position - bake_params.to_cell_offset) * bake_params.to_cell_size;
345										if (icell != ivec3(hit_cell)) {
346											// It's possible for the ray to hit a triangle in a position outside the bounds of the cell
347											// if it's large enough to cover multiple ones. The hit must be ignored if this is the case.
348											continue;
349										}
350		
351										if (!backface) {
352											// The case of meshes having both a front and back face in the same plane is more common than
353											// expected, so if this is a front-face, bias it closer to the ray origin, so it always wins
354											// over the back-face.
355											distance = max(bake_params.bias, distance - bake_params.bias);
356										}
357		
358										if (distance < best_distance) {
359											hit = backface ? RAY_BACK : RAY_FRONT;
360											best_distance = distance;
361											r_distance = distance;
362											r_normal = normal;
363											r_triangle = triangle_index;
364											r_barycentric = barycentric;
365										}
366									}
367								}
368		
369		#ifdef CLUSTER_TRIANGLE_ITERATION
370								triangle_base_index += CLUSTER_SIZE;
371		#endif
372							}
373						}
374		
375						cluster_base_index += 32;
376					}
377		
378					if (hit != RAY_MISS) {
379						return hit;
380					}
381				}
382		
383				if (icell == iendcell) {
384					break;
385				}
386		
387				bvec3 mask = lessThanEqual(side.xyz, min(side.yzx, side.zxy));
388				side += vec3(mask) * delta;
389				icell += ivec3(vec3(mask)) * step;
390				iters++;
391			}
392		
393			return RAY_MISS;
394		}
395		
396		uint trace_ray_closest_hit_triangle(vec3 p_from, vec3 p_to, out uint r_triangle, out vec3 r_barycentric) {
397			float distance;
398			vec3 normal;
399			return trace_ray(p_from, p_to, false, distance, normal, r_triangle, r_barycentric);
400		}
401		
402		uint trace_ray_closest_hit_distance(vec3 p_from, vec3 p_to, out float r_distance, out vec3 r_normal) {
403			uint triangle;
404			vec3 barycentric;
405			return trace_ray(p_from, p_to, false, r_distance, r_normal, triangle, barycentric);
406		}
407		
408		uint trace_ray_any_hit(vec3 p_from, vec3 p_to) {
409			float distance;
410			vec3 normal;
411			uint triangle;
412			vec3 barycentric;
413			return trace_ray(p_from, p_to, true, distance, normal, triangle, barycentric);
414		}
415		
416		// https://www.reedbeta.com/blog/hash-functions-for-gpu-rendering/
417		uint hash(uint value) {
418			uint state = value * 747796405u + 2891336453u;
419			uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
420			return (word >> 22u) ^ word;
421		}
422		
423		uint random_seed(ivec3 seed) {
424			return hash(seed.x ^ hash(seed.y ^ hash(seed.z)));
425		}
426		
427		// generates a random value in range [0.0, 1.0)
428		float randomize(inout uint value) {
429			value = hash(value);
430			return float(value / 4294967296.0);
431		}
432		
433		const float PI = 3.14159265f;
434		
435		// http://www.realtimerendering.com/raytracinggems/unofficial_RayTracingGems_v1.4.pdf (chapter 15)
436		vec3 generate_hemisphere_cosine_weighted_direction(inout uint noise) {
437			float noise1 = randomize(noise);
438			float noise2 = randomize(noise) * 2.0 * PI;
439		
440			return vec3(sqrt(noise1) * cos(noise2), sqrt(noise1) * sin(noise2), sqrt(1.0 - noise1));
441		}
442		
443		// Distribution generation adapted from "Generating uniformly distributed numbers on a sphere"
444		// <http://corysimon.github.io/articles/uniformdistn-on-sphere/>
445		vec3 generate_sphere_uniform_direction(inout uint noise) {
446			float theta = 2.0 * PI * randomize(noise);
447			float phi = acos(1.0 - 2.0 * randomize(noise));
448			return vec3(sin(phi) * cos(theta), sin(phi) * sin(theta), cos(phi));
449		}
450		
451		vec3 generate_ray_dir_from_normal(vec3 normal, inout uint noise) {
452			vec3 v0 = abs(normal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
453			vec3 tangent = normalize(cross(v0, normal));
454			vec3 bitangent = normalize(cross(tangent, normal));
455			mat3 normal_mat = mat3(tangent, bitangent, normal);
456			return normal_mat * generate_hemisphere_cosine_weighted_direction(noise);
457		}
458		
459		#if defined(MODE_DIRECT_LIGHT) || defined(MODE_BOUNCE_LIGHT) || defined(MODE_LIGHT_PROBES)
460		
461		float get_omni_attenuation(float distance, float inv_range, float decay) {
462			float nd = distance * inv_range;
463			nd *= nd;
464			nd *= nd; // nd^4
465			nd = max(1.0 - nd, 0.0);
466			nd *= nd; // nd^2
467			return nd * pow(max(distance, 0.0001), -decay);
468		}
469		
470		void trace_direct_light(vec3 p_position, vec3 p_normal, uint p_light_index, bool p_soft_shadowing, out vec3 r_light, out vec3 r_light_dir, inout uint r_noise) {
471			r_light = vec3(0.0f);
472		
473			vec3 light_pos;
474			float dist;
475			float attenuation;
476			float soft_shadowing_disk_size;
477			Light light_data = lights.data[p_light_index];
478			if (light_data.type == LIGHT_TYPE_DIRECTIONAL) {
479				vec3 light_vec = light_data.direction;
480				light_pos = p_position - light_vec * length(bake_params.world_size);
481				r_light_dir = normalize(light_pos - p_position);
482				dist = length(bake_params.world_size);
483				attenuation = 1.0;
484				soft_shadowing_disk_size = light_data.size;
485			} else {
486				light_pos = light_data.position;
487				r_light_dir = normalize(light_pos - p_position);
488				dist = distance(p_position, light_pos);
489				if (dist > light_data.range) {
490					return;
491				}
492		
493				soft_shadowing_disk_size = light_data.size / dist;
494		
495				attenuation = get_omni_attenuation(dist, 1.0 / light_data.range, light_data.attenuation);
496		
497				if (light_data.type == LIGHT_TYPE_SPOT) {
498					vec3 rel = normalize(p_position - light_pos);
499					float cos_spot_angle = light_data.cos_spot_angle;
500					float cos_angle = dot(rel, light_data.direction);
501		
502					if (cos_angle < cos_spot_angle) {
503						return;
504					}
505		
506					float scos = max(cos_angle, cos_spot_angle);
507					float spot_rim = max(0.0001, (1.0 - scos) / (1.0 - cos_spot_angle));
508					attenuation *= 1.0 - pow(spot_rim, light_data.inv_spot_attenuation);
509				}
510			}
511		
512			attenuation *= max(0.0, dot(p_normal, r_light_dir));
513			if (attenuation <= 0.0001) {
514				return;
515			}
516		
517			float penumbra = 0.0;
518			if ((light_data.size > 0.0) && p_soft_shadowing) {
519				vec3 light_to_point = -r_light_dir;
520				vec3 aux = light_to_point.y < 0.777 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
521				vec3 light_to_point_tan = normalize(cross(light_to_point, aux));
522				vec3 light_to_point_bitan = normalize(cross(light_to_point, light_to_point_tan));
523		
524				const uint shadowing_rays_check_penumbra_denom = 2;
525				uint shadowing_ray_count = p_soft_shadowing ? params.ray_count : 1;
526		
527				uint hits = 0;
528				vec3 light_disk_to_point = light_to_point;
529				for (uint j = 0; j < shadowing_ray_count; j++) {
530					// Optimization:
531					// Once already traced an important proportion of rays, if all are hits or misses,
532					// assume we're not in the penumbra so we can infer the rest would have the same result
533					if (p_soft_shadowing) {
534						if (j == shadowing_ray_count / shadowing_rays_check_penumbra_denom) {
535							if (hits == j) {
536								// Assume totally lit
537								hits = shadowing_ray_count;
538								break;
539							} else if (hits == 0) {
540								// Assume totally dark
541								hits = 0;
542								break;
543							}
544						}
545					}
546		
547					float r = randomize(r_noise);
548					float a = randomize(r_noise) * 2.0 * PI;
549					vec2 disk_sample = (r * vec2(cos(a), sin(a))) * soft_shadowing_disk_size * light_data.shadow_blur;
550					light_disk_to_point = normalize(light_to_point + disk_sample.x * light_to_point_tan + disk_sample.y * light_to_point_bitan);
551		
552					if (trace_ray_any_hit(p_position - light_disk_to_point * bake_params.bias, p_position - light_disk_to_point * dist) == RAY_MISS) {
553						hits++;
554					}
555				}
556		
557				penumbra = float(hits) / float(shadowing_ray_count);
558			} else {
559				if (trace_ray_any_hit(p_position + r_light_dir * bake_params.bias, light_pos) == RAY_MISS) {
560					penumbra = 1.0;
561				}
562			}
563		
564			r_light = light_data.color * light_data.energy * attenuation * penumbra;
565		}
566		
567		#endif
568		
569		#if defined(MODE_BOUNCE_LIGHT) || defined(MODE_LIGHT_PROBES)
570		
571		vec3 trace_environment_color(vec3 ray_dir) {
572			vec3 sky_dir = normalize(mat3(bake_params.env_transform) * ray_dir);
573			vec2 st = vec2(atan(sky_dir.x, sky_dir.z), acos(sky_dir.y));
574			if (st.x < 0.0) {
575				st.x += PI * 2.0;
576			}
577		
578			return textureLod(sampler2D(environment, linear_sampler), st / vec2(PI * 2.0, PI), 0.0).rgb;
579		}
580		
581		vec3 trace_indirect_light(vec3 p_position, vec3 p_ray_dir, inout uint r_noise) {
582			// The lower limit considers the case where the lightmapper might have bounces disabled but light probes are requested.
583			vec3 position = p_position;
584			vec3 ray_dir = p_ray_dir;
585			uint max_depth = max(bake_params.bounces, 1);
586			vec3 throughput = vec3(1.0);
587			vec3 light = vec3(0.0);
588			for (uint depth = 0; depth < max_depth; depth++) {
589				uint tidx;
590				vec3 barycentric;
591				uint trace_result = trace_ray_closest_hit_triangle(position + ray_dir * bake_params.bias, position + ray_dir * length(bake_params.world_size), tidx, barycentric);
592				if (trace_result == RAY_FRONT) {
593					Vertex vert0 = vertices.data[triangles.data[tidx].indices.x];
594					Vertex vert1 = vertices.data[triangles.data[tidx].indices.y];
595					Vertex vert2 = vertices.data[triangles.data[tidx].indices.z];
596					vec3 uvw = vec3(barycentric.x * vert0.uv + barycentric.y * vert1.uv + barycentric.z * vert2.uv, float(triangles.data[tidx].slice));
597					position = barycentric.x * vert0.position + barycentric.y * vert1.position + barycentric.z * vert2.position;
598		
599					vec3 norm0 = vec3(vert0.normal_xy, vert0.normal_z);
600					vec3 norm1 = vec3(vert1.normal_xy, vert1.normal_z);
601					vec3 norm2 = vec3(vert2.normal_xy, vert2.normal_z);
602					vec3 normal = barycentric.x * norm0 + barycentric.y * norm1 + barycentric.z * norm2;
603		
604					vec3 direct_light = vec3(0.0f);
605		#ifdef USE_LIGHT_TEXTURE_FOR_BOUNCES
606					direct_light += textureLod(sampler2DArray(source_light, linear_sampler), uvw, 0.0).rgb;
607		#else
608					// Trace the lights directly. Significantly more expensive but more accurate in scenarios
609					// where the lightmap texture isn't reliable.
610					for (uint i = 0; i < bake_params.light_count; i++) {
611						vec3 light;
612						vec3 light_dir;
613						trace_direct_light(position, normal, i, false, light, light_dir, r_noise);
614						direct_light += light * lights.data[i].indirect_energy;
615					}
616		
617					direct_light *= bake_params.exposure_normalization;
618		#endif
619		
620					vec3 albedo = textureLod(sampler2DArray(albedo_tex, linear_sampler), uvw, 0).rgb;
621					vec3 emissive = textureLod(sampler2DArray(emission_tex, linear_sampler), uvw, 0).rgb;
622					emissive *= bake_params.exposure_normalization;
623		
624					light += throughput * emissive;
625					throughput *= albedo;
626					light += throughput * direct_light * bake_params.bounce_indirect_energy;
627		
628					// Use Russian Roulette to determine a probability to terminate the bounce earlier as an optimization.
629					// <https://computergraphics.stackexchange.com/questions/2316/is-russian-roulette-really-the-answer>
630					float p = max(max(throughput.x, throughput.y), throughput.z);
631					if (randomize(r_noise) > p) {
632						break;
633					}
634		
635					// Boost the throughput from the probability of the ray being terminated early.
636					throughput *= 1.0 / p;
637		
638					// Generate a new ray direction for the next bounce from this surface's normal.
639					ray_dir = generate_ray_dir_from_normal(normal, r_noise);
640				} else if (trace_result == RAY_MISS) {
641					// Look for the environment color and stop bouncing.
642					light += throughput * trace_environment_color(ray_dir);
643					break;
644				} else {
645					// Ignore any other trace results.
646					break;
647				}
648			}
649		
650			return light;
651		}
652		
653		#endif
654		
655		void main() {
656			// Check if invocation is out of bounds.
657		#ifdef MODE_LIGHT_PROBES
658			int probe_index = int(gl_GlobalInvocationID.x);
659			if (probe_index >= params.probe_count) {
660				return;
661			}
662		
663		#else
664			ivec2 atlas_pos = ivec2(gl_GlobalInvocationID.xy) + params.region_ofs;
665			if (any(greaterThanEqual(atlas_pos, bake_params.atlas_size))) {
666				return;
667			}
668		#endif
669		
670		#ifdef MODE_DIRECT_LIGHT
671		
672			vec3 normal = texelFetch(sampler2DArray(source_normal, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).xyz;
673			if (length(normal) < 0.5) {
674				return; //empty texel, no process
675			}
676			vec3 position = texelFetch(sampler2DArray(source_position, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).xyz;
677			vec3 light_for_texture = vec3(0.0);
678			vec3 light_for_bounces = vec3(0.0);
679		
680		#ifdef USE_SH_LIGHTMAPS
681			vec4 sh_accum[4] = vec4[](
682					vec4(0.0, 0.0, 0.0, 1.0),
683					vec4(0.0, 0.0, 0.0, 1.0),
684					vec4(0.0, 0.0, 0.0, 1.0),
685					vec4(0.0, 0.0, 0.0, 1.0));
686		#endif
687		
688			// Use atlas position and a prime number as the seed.
689			uint noise = random_seed(ivec3(atlas_pos, 43573547));
690			for (uint i = 0; i < bake_params.light_count; i++) {
691				vec3 light;
692				vec3 light_dir;
693				trace_direct_light(position, normal, i, true, light, light_dir, noise);
694		
695				if (lights.data[i].static_bake) {
696					light_for_texture += light;
697		
698		#ifdef USE_SH_LIGHTMAPS
699					float c[4] = float[](
700							0.282095, //l0
701							0.488603 * light_dir.y, //l1n1
702							0.488603 * light_dir.z, //l1n0
703							0.488603 * light_dir.x //l1p1
704					);
705		
706					for (uint j = 0; j < 4; j++) {
707						sh_accum[j].rgb += light * c[j] * 8.0;
708					}
709		#endif
710				}
711		
712				light_for_bounces += light * lights.data[i].indirect_energy;
713			}
714		
715			light_for_bounces *= bake_params.exposure_normalization;
716			imageStore(dest_light, ivec3(atlas_pos, params.atlas_slice), vec4(light_for_bounces, 1.0));
717		
718		#ifdef USE_SH_LIGHTMAPS
719			// Keep for adding at the end.
720			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + 0), sh_accum[0]);
721			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + 1), sh_accum[1]);
722			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + 2), sh_accum[2]);
723			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + 3), sh_accum[3]);
724		#else
725			light_for_texture *= bake_params.exposure_normalization;
726			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice), vec4(light_for_texture, 1.0));
727		#endif
728		
729		#endif
730		
731		#ifdef MODE_BOUNCE_LIGHT
732		
733		#ifdef USE_SH_LIGHTMAPS
734			vec4 sh_accum[4] = vec4[](
735					vec4(0.0, 0.0, 0.0, 1.0),
736					vec4(0.0, 0.0, 0.0, 1.0),
737					vec4(0.0, 0.0, 0.0, 1.0),
738					vec4(0.0, 0.0, 0.0, 1.0));
739		#else
740			vec3 light_accum = vec3(0.0);
741		#endif
742		
743			// Retrieve starting normal and position.
744			vec3 normal = texelFetch(sampler2DArray(source_normal, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).xyz;
745			if (length(normal) < 0.5) {
746				// The pixel is empty, skip processing it.
747				return;
748			}
749		
750			vec3 position = texelFetch(sampler2DArray(source_position, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).xyz;
751			uint noise = random_seed(ivec3(params.ray_from, atlas_pos));
752			for (uint i = params.ray_from; i < params.ray_to; i++) {
753				vec3 ray_dir = generate_ray_dir_from_normal(normal, noise);
754				vec3 light = trace_indirect_light(position, ray_dir, noise);
755		
756		#ifdef USE_SH_LIGHTMAPS
757				float c[4] = float[](
758						0.282095, //l0
759						0.488603 * ray_dir.y, //l1n1
760						0.488603 * ray_dir.z, //l1n0
761						0.488603 * ray_dir.x //l1p1
762				);
763		
764				for (uint j = 0; j < 4; j++) {
765					sh_accum[j].rgb += light * c[j] * 8.0;
766				}
767		#else
768				light_accum += light;
769		#endif
770			}
771		
772			// Add the averaged result to the accumulated light texture.
773		#ifdef USE_SH_LIGHTMAPS
774			for (int i = 0; i < 4; i++) {
775				vec4 accum = imageLoad(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + i));
776				accum.rgb += sh_accum[i].rgb / float(params.ray_count);
777				imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + i), accum);
778			}
779		#else
780			vec4 accum = imageLoad(accum_light, ivec3(atlas_pos, params.atlas_slice));
781			accum.rgb += light_accum / float(params.ray_count);
782			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice), accum);
783		#endif
784		
785		#endif
786		
787		#ifdef MODE_UNOCCLUDE
788		
789			//texel_size = 0.5;
790			//compute tangents
791		
792			vec4 position_alpha = imageLoad(position, ivec3(atlas_pos, params.atlas_slice));
793			if (position_alpha.a < 0.5) {
794				return;
795			}
796		
797			vec3 vertex_pos = position_alpha.xyz;
798			vec4 normal_tsize = imageLoad(unocclude, ivec3(atlas_pos, params.atlas_slice));
799		
800			vec3 face_normal = normal_tsize.xyz;
801			float texel_size = normal_tsize.w;
802		
803			vec3 v0 = abs(face_normal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
804			vec3 tangent = normalize(cross(v0, face_normal));
805			vec3 bitangent = normalize(cross(tangent, face_normal));
806			vec3 base_pos = vertex_pos + face_normal * bake_params.bias; // Raise a bit.
807		
808			vec3 rays[4] = vec3[](tangent, bitangent, -tangent, -bitangent);
809			float min_d = 1e20;
810			for (int i = 0; i < 4; i++) {
811				vec3 ray_to = base_pos + rays[i] * texel_size;
812				float d;
813				vec3 norm;
814		
815				if (trace_ray_closest_hit_distance(base_pos, ray_to, d, norm) == RAY_BACK) {
816					if (d < min_d) {
817						// This bias needs to be greater than the regular bias, because otherwise later, rays will go the other side when pointing back.
818						vertex_pos = base_pos + rays[i] * d + norm * bake_params.bias * 10.0;
819						min_d = d;
820					}
821				}
822			}
823		
824			position_alpha.xyz = vertex_pos;
825		
826			imageStore(position, ivec3(atlas_pos, params.atlas_slice), position_alpha);
827		
828		#endif
829		
830		#ifdef MODE_LIGHT_PROBES
831		
832			vec3 position = probe_positions.data[probe_index].xyz;
833		
834			vec4 probe_sh_accum[9] = vec4[](
835					vec4(0.0),
836					vec4(0.0),
837					vec4(0.0),
838					vec4(0.0),
839					vec4(0.0),
840					vec4(0.0),
841					vec4(0.0),
842					vec4(0.0),
843					vec4(0.0));
844		
845			uint noise = random_seed(ivec3(params.ray_from, probe_index, 49502741 /* some prime */));
846			for (uint i = params.ray_from; i < params.ray_to; i++) {
847				vec3 ray_dir = generate_sphere_uniform_direction(noise);
848				vec3 light = trace_indirect_light(position, ray_dir, noise);
849		
850				float c[9] = float[](
851						0.282095, //l0
852						0.488603 * ray_dir.y, //l1n1
853						0.488603 * ray_dir.z, //l1n0
854						0.488603 * ray_dir.x, //l1p1
855						1.092548 * ray_dir.x * ray_dir.y, //l2n2
856						1.092548 * ray_dir.y * ray_dir.z, //l2n1
857						//0.315392 * (ray_dir.x * ray_dir.x + ray_dir.y * ray_dir.y + 2.0 * ray_dir.z * ray_dir.z), //l20
858						0.315392 * (3.0 * ray_dir.z * ray_dir.z - 1.0), //l20
859						1.092548 * ray_dir.x * ray_dir.z, //l2p1
860						0.546274 * (ray_dir.x * ray_dir.x - ray_dir.y * ray_dir.y) //l2p2
861				);
862		
863				for (uint j = 0; j < 9; j++) {
864					probe_sh_accum[j].rgb += light * c[j];
865				}
866			}
867		
868			if (params.ray_from > 0) {
869				for (uint j = 0; j < 9; j++) { //accum from existing
870					probe_sh_accum[j] += light_probes.data[probe_index * 9 + j];
871				}
872			}
873		
874			if (params.ray_to == params.ray_count) {
875				for (uint j = 0; j < 9; j++) { //accum from existing
876					probe_sh_accum[j] *= 4.0 / float(params.ray_count);
877				}
878			}
879		
880			for (uint j = 0; j < 9; j++) { //accum from existing
881				light_probes.data[probe_index * 9 + j] = probe_sh_accum[j];
882			}
883		
884		#endif
885		
886		#ifdef MODE_DILATE
887		
888			vec4 c = texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0);
889			//sides first, as they are closer
890			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-1, 0), params.atlas_slice), 0);
891			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(0, 1), params.atlas_slice), 0);
892			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(1, 0), params.atlas_slice), 0);
893			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(0, -1), params.atlas_slice), 0);
894			//endpoints second
895			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-1, -1), params.atlas_slice), 0);
896			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-1, 1), params.atlas_slice), 0);
897			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(1, -1), params.atlas_slice), 0);
898			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(1, 1), params.atlas_slice), 0);
899		
900			//far sides third
901			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-2, 0), params.atlas_slice), 0);
902			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(0, 2), params.atlas_slice), 0);
903			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(2, 0), params.atlas_slice), 0);
904			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(0, -2), params.atlas_slice), 0);
905		
906			//far-mid endpoints
907			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-2, -1), params.atlas_slice), 0);
908			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-2, 1), params.atlas_slice), 0);
909			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(2, -1), params.atlas_slice), 0);
910			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(2, 1), params.atlas_slice), 0);
911		
912			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-1, -2), params.atlas_slice), 0);
913			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-1, 2), params.atlas_slice), 0);
914			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(1, -2), params.atlas_slice), 0);
915			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(1, 2), params.atlas_slice), 0);
916			//far endpoints
917			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-2, -2), params.atlas_slice), 0);
918			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-2, 2), params.atlas_slice), 0);
919			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(2, -2), params.atlas_slice), 0);
920			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(2, 2), params.atlas_slice), 0);
921		
922			imageStore(dest_light, ivec3(atlas_pos, params.atlas_slice), c);
923		
924		#endif
925		
926		#ifdef MODE_DENOISE
927			// Joint Non-local means (JNLM) denoiser.
928			//
929			// Based on YoctoImageDenoiser's JNLM implementation with corrections from "Nonlinearly Weighted First-order Regression for Denoising Monte Carlo Renderings".
930			//
931			// <https://github.com/ManuelPrandini/YoctoImageDenoiser/blob/06e19489dd64e47792acffde536393802ba48607/libs/yocto_extension/yocto_extension.cpp#L207>
932			// <https://benedikt-bitterli.me/nfor/nfor.pdf>
933			//
934			// MIT License
935			//
936			// Copyright (c) 2020 ManuelPrandini
937			//
938			// Permission is hereby granted, free of charge, to any person obtaining a copy
939			// of this software and associated documentation files (the "Software"), to deal
940			// in the Software without restriction, including without limitation the rights
941			// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
942			// copies of the Software, and to permit persons to whom the Software is
943			// furnished to do so, subject to the following conditions:
944			//
945			// The above copyright notice and this permission notice shall be included in all
946			// copies or substantial portions of the Software.
947			//
948			// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
949			// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
950			// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
951			// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
952			// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
953			// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
954			// SOFTWARE.
955			//
956			// Most of the constants below have been hand-picked to fit the common scenarios lightmaps
957			// are generated with, but they can be altered freely to experiment and achieve better results.
958		
959			// Half the size of the patch window around each pixel that is weighted to compute the denoised pixel.
960			// A value of 1 represents a 3x3 window, a value of 2 a 5x5 window, etc.
961			const int HALF_PATCH_WINDOW = 4;
962		
963			// Half the size of the search window around each pixel that is denoised and weighted to compute the denoised pixel.
964			const int HALF_SEARCH_WINDOW = 10;
965		
966			// For all of the following sigma values, smaller values will give less weight to pixels that have a bigger distance
967			// in the feature being evaluated. Therefore, smaller values are likely to cause more noise to appear, but will also
968			// cause less features to be erased in the process.
969		
970			// Controls how much the spatial distance of the pixels influences the denoising weight.
971			const float SIGMA_SPATIAL = denoise_params.spatial_bandwidth;
972		
973			// Controls how much the light color distance of the pixels influences the denoising weight.
974			const float SIGMA_LIGHT = denoise_params.light_bandwidth;
975		
976			// Controls how much the albedo color distance of the pixels influences the denoising weight.
977			const float SIGMA_ALBEDO = denoise_params.albedo_bandwidth;
978		
979			// Controls how much the normal vector distance of the pixels influences the denoising weight.
980			const float SIGMA_NORMAL = denoise_params.normal_bandwidth;
981		
982			// Strength of the filter. The original paper recommends values around 10 to 15 times the Sigma parameter.
983			const float FILTER_VALUE = denoise_params.filter_strength * SIGMA_LIGHT;
984		
985			// Formula constants.
986			const int PATCH_WINDOW_DIMENSION = (HALF_PATCH_WINDOW * 2 + 1);
987			const int PATCH_WINDOW_DIMENSION_SQUARE = (PATCH_WINDOW_DIMENSION * PATCH_WINDOW_DIMENSION);
988			const float TWO_SIGMA_SPATIAL_SQUARE = 2.0f * SIGMA_SPATIAL * SIGMA_SPATIAL;
989			const float TWO_SIGMA_LIGHT_SQUARE = 2.0f * SIGMA_LIGHT * SIGMA_LIGHT;
990			const float TWO_SIGMA_ALBEDO_SQUARE = 2.0f * SIGMA_ALBEDO * SIGMA_ALBEDO;
991			const float TWO_SIGMA_NORMAL_SQUARE = 2.0f * SIGMA_NORMAL * SIGMA_NORMAL;
992			const float FILTER_SQUARE_TWO_SIGMA_LIGHT_SQUARE = FILTER_VALUE * FILTER_VALUE * TWO_SIGMA_LIGHT_SQUARE;
993			const float EPSILON = 1e-6f;
994		
995		#ifdef USE_SH_LIGHTMAPS
996			const uint slice_count = 4;
997			const uint slice_base = params.atlas_slice * slice_count;
998		#else
999			const uint slice_count = 1;
1000			const uint slice_base = params.atlas_slice;
1001		#endif
1002		
1003			for (uint i = 0; i < slice_count; i++) {
1004				uint lightmap_slice = slice_base + i;
1005				vec3 denoised_rgb = vec3(0.0f);
1006				vec4 input_light = texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos, lightmap_slice), 0);
1007				vec3 input_albedo = texelFetch(sampler2DArray(albedo_tex, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).rgb;
1008				vec3 input_normal = texelFetch(sampler2DArray(source_normal, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).xyz;
1009				if (length(input_normal) > EPSILON) {
1010					// Compute the denoised pixel if the normal is valid.
1011					float sum_weights = 0.0f;
1012					vec3 input_rgb = input_light.rgb;
1013					for (int search_y = -HALF_SEARCH_WINDOW; search_y <= HALF_SEARCH_WINDOW; search_y++) {
1014						for (int search_x = -HALF_SEARCH_WINDOW; search_x <= HALF_SEARCH_WINDOW; search_x++) {
1015							ivec2 search_pos = atlas_pos + ivec2(search_x, search_y);
1016							vec3 search_rgb = texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(search_pos, lightmap_slice), 0).rgb;
1017							vec3 search_albedo = texelFetch(sampler2DArray(albedo_tex, linear_sampler), ivec3(search_pos, params.atlas_slice), 0).rgb;
1018							vec3 search_normal = texelFetch(sampler2DArray(source_normal, linear_sampler), ivec3(search_pos, params.atlas_slice), 0).xyz;
1019							float patch_square_dist = 0.0f;
1020							for (int offset_y = -HALF_PATCH_WINDOW; offset_y <= HALF_PATCH_WINDOW; offset_y++) {
1021								for (int offset_x = -HALF_PATCH_WINDOW; offset_x <= HALF_PATCH_WINDOW; offset_x++) {
1022									ivec2 offset_input_pos = atlas_pos + ivec2(offset_x, offset_y);
1023									ivec2 offset_search_pos = search_pos + ivec2(offset_x, offset_y);
1024									vec3 offset_input_rgb = texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(offset_input_pos, lightmap_slice), 0).rgb;
1025									vec3 offset_search_rgb = texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(offset_search_pos, lightmap_slice), 0).rgb;
1026									vec3 offset_delta_rgb = offset_input_rgb - offset_search_rgb;
1027									patch_square_dist += dot(offset_delta_rgb, offset_delta_rgb) - TWO_SIGMA_LIGHT_SQUARE;
1028								}
1029							}
1030		
1031							patch_square_dist = max(0.0f, patch_square_dist / (3.0f * PATCH_WINDOW_DIMENSION_SQUARE));
1032		
1033							float weight = 1.0f;
1034		
1035							// Ignore weight if search position is out of bounds.
1036							weight *= step(0, search_pos.x) * step(search_pos.x, bake_params.atlas_size.x - 1);
1037							weight *= step(0, search_pos.y) * step(search_pos.y, bake_params.atlas_size.y - 1);
1038		
1039							// Ignore weight if normal is zero length.
1040							weight *= step(EPSILON, length(search_normal));
1041		
1042							// Weight with pixel distance.
1043							vec2 pixel_delta = vec2(search_x, search_y);
1044							float pixel_square_dist = dot(pixel_delta, pixel_delta);
1045							weight *= exp(-pixel_square_dist / TWO_SIGMA_SPATIAL_SQUARE);
1046		
1047							// Weight with patch.
1048							weight *= exp(-patch_square_dist / FILTER_SQUARE_TWO_SIGMA_LIGHT_SQUARE);
1049		
1050							// Weight with albedo.
1051							vec3 albedo_delta = input_albedo - search_albedo;
1052							float albedo_square_dist = dot(albedo_delta, albedo_delta);
1053							weight *= exp(-albedo_square_dist / TWO_SIGMA_ALBEDO_SQUARE);
1054		
1055							// Weight with normal.
1056							vec3 normal_delta = input_normal - search_normal;
1057							float normal_square_dist = dot(normal_delta, normal_delta);
1058							weight *= exp(-normal_square_dist / TWO_SIGMA_NORMAL_SQUARE);
1059		
1060							denoised_rgb += weight * search_rgb;
1061							sum_weights += weight;
1062						}
1063					}
1064		
1065					denoised_rgb /= sum_weights;
1066				} else {
1067					// Ignore pixels where the normal is empty, just copy the light color.
1068					denoised_rgb = input_light.rgb;
1069				}
1070		
1071				imageStore(dest_light, ivec3(atlas_pos, lightmap_slice), vec4(denoised_rgb, input_light.a));
1072			}
1073		#endif
1074		}
1075		
1076		
          RDShaderSPIRV          ­  Failed parse:
ERROR: 0:282: 'CLUSTER_SIZE' : undeclared identifier 
ERROR: 0:282: '' : compilation terminated 
ERROR: 2 compilation errors.  No code generated.




Stage 'compute' source code: 

1		
2		#version 450
3		
4		#
5		#define MODE_BOUNCE_LIGHT
6		
7		
8		
9		// One 2D local group focusing in one layer at a time, though all
10		// in parallel (no barriers) makes more sense than a 3D local group
11		// as this can take more advantage of the cache for each group.
12		
13		#ifdef MODE_LIGHT_PROBES
14		
15		layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
16		
17		#else
18		
19		layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
20		
21		#endif
22		
23		
24		
25		/* SET 0, static data that does not change between any call */
26		
27		layout(set = 0, binding = 0) uniform BakeParameters {
28			vec3 world_size;
29			float bias;
30		
31			vec3 to_cell_offset;
32			int grid_size;
33		
34			vec3 to_cell_size;
35			uint light_count;
36		
37			mat3x4 env_transform;
38		
39			ivec2 atlas_size;
40			float exposure_normalization;
41			uint bounces;
42		
43			float bounce_indirect_energy;
44		}
45		bake_params;
46		
47		struct Vertex {
48			vec3 position;
49			float normal_z;
50			vec2 uv;
51			vec2 normal_xy;
52		};
53		
54		layout(set = 0, binding = 1, std430) restrict readonly buffer Vertices {
55			Vertex data[];
56		}
57		vertices;
58		
59		struct Triangle {
60			uvec3 indices;
61			uint slice;
62			vec3 min_bounds;
63			uint pad0;
64			vec3 max_bounds;
65			uint pad1;
66		};
67		
68		struct ClusterAABB {
69			vec3 min_bounds;
70			uint pad0;
71			vec3 max_bounds;
72			uint pad1;
73		};
74		
75		layout(set = 0, binding = 2, std430) restrict readonly buffer Triangles {
76			Triangle data[];
77		}
78		triangles;
79		
80		layout(set = 0, binding = 3, std430) restrict readonly buffer TriangleIndices {
81			uint data[];
82		}
83		triangle_indices;
84		
85		#define LIGHT_TYPE_DIRECTIONAL 0
86		#define LIGHT_TYPE_OMNI 1
87		#define LIGHT_TYPE_SPOT 2
88		
89		struct Light {
90			vec3 position;
91			uint type;
92		
93			vec3 direction;
94			float energy;
95		
96			vec3 color;
97			float size;
98		
99			float range;
100			float attenuation;
101			float cos_spot_angle;
102			float inv_spot_attenuation;
103		
104			float indirect_energy;
105			float shadow_blur;
106			bool static_bake;
107			uint pad;
108		};
109		
110		layout(set = 0, binding = 4, std430) restrict readonly buffer Lights {
111			Light data[];
112		}
113		lights;
114		
115		struct Seam {
116			uvec2 a;
117			uvec2 b;
118		};
119		
120		layout(set = 0, binding = 5, std430) restrict readonly buffer Seams {
121			Seam data[];
122		}
123		seams;
124		
125		layout(set = 0, binding = 6, std430) restrict readonly buffer Probes {
126			vec4 data[];
127		}
128		probe_positions;
129		
130		layout(set = 0, binding = 7) uniform utexture3D grid;
131		
132		layout(set = 0, binding = 8) uniform texture2DArray albedo_tex;
133		layout(set = 0, binding = 9) uniform texture2DArray emission_tex;
134		
135		layout(set = 0, binding = 10) uniform sampler linear_sampler;
136		
137		layout(set = 0, binding = 11, std430) restrict readonly buffer ClusterIndices {
138			uint data[];
139		}
140		cluster_indices;
141		
142		layout(set = 0, binding = 12, std430) restrict readonly buffer ClusterAABBs {
143			ClusterAABB data[];
144		}
145		cluster_aabbs;
146		
147		// Fragment action constants
148		const uint FA_NONE = 0;
149		const uint FA_SMOOTHEN_POSITION = 1;
150		
151		
152		#ifdef MODE_LIGHT_PROBES
153		
154		layout(set = 1, binding = 0, std430) restrict buffer LightProbeData {
155			vec4 data[];
156		}
157		light_probes;
158		
159		layout(set = 1, binding = 1) uniform texture2DArray source_light;
160		layout(set = 1, binding = 2) uniform texture2D environment;
161		#endif
162		
163		#ifdef MODE_UNOCCLUDE
164		
165		layout(rgba32f, set = 1, binding = 0) uniform restrict image2DArray position;
166		layout(rgba32f, set = 1, binding = 1) uniform restrict readonly image2DArray unocclude;
167		
168		#endif
169		
170		#if defined(MODE_DIRECT_LIGHT) || defined(MODE_BOUNCE_LIGHT)
171		
172		layout(rgba16f, set = 1, binding = 0) uniform restrict writeonly image2DArray dest_light;
173		layout(set = 1, binding = 1) uniform texture2DArray source_light;
174		layout(set = 1, binding = 2) uniform texture2DArray source_position;
175		layout(set = 1, binding = 3) uniform texture2DArray source_normal;
176		layout(rgba16f, set = 1, binding = 4) uniform restrict image2DArray accum_light;
177		
178		#endif
179		
180		#ifdef MODE_BOUNCE_LIGHT
181		layout(set = 1, binding = 5) uniform texture2D environment;
182		#endif
183		
184		#if defined(MODE_DILATE) || defined(MODE_DENOISE)
185		layout(rgba16f, set = 1, binding = 0) uniform restrict writeonly image2DArray dest_light;
186		layout(set = 1, binding = 1) uniform texture2DArray source_light;
187		#endif
188		
189		#ifdef MODE_DENOISE
190		layout(set = 1, binding = 2) uniform texture2DArray source_normal;
191		layout(set = 1, binding = 3) uniform DenoiseParams {
192			float spatial_bandwidth;
193			float light_bandwidth;
194			float albedo_bandwidth;
195			float normal_bandwidth;
196		
197			float filter_strength;
198		}
199		denoise_params;
200		#endif
201		
202		layout(push_constant, std430) uniform Params {
203			uint atlas_slice;
204			uint ray_count;
205			uint ray_from;
206			uint ray_to;
207		
208			ivec2 region_ofs;
209			uint probe_count;
210		}
211		params;
212		
213		//check it, but also return distance and barycentric coords (for uv lookup)
214		bool ray_hits_triangle(vec3 from, vec3 dir, float max_dist, vec3 p0, vec3 p1, vec3 p2, out float r_distance, out vec3 r_barycentric) {
215			const float EPSILON = 0.00001;
216			const vec3 e0 = p1 - p0;
217			const vec3 e1 = p0 - p2;
218			vec3 triangle_normal = cross(e1, e0);
219		
220			float n_dot_dir = dot(triangle_normal, dir);
221		
222			if (abs(n_dot_dir) < EPSILON) {
223				return false;
224			}
225		
226			const vec3 e2 = (p0 - from) / n_dot_dir;
227			const vec3 i = cross(dir, e2);
228		
229			r_barycentric.y = dot(i, e1);
230			r_barycentric.z = dot(i, e0);
231			r_barycentric.x = 1.0 - (r_barycentric.z + r_barycentric.y);
232			r_distance = dot(triangle_normal, e2);
233		
234			return (r_distance > bake_params.bias) && (r_distance < max_dist) && all(greaterThanEqual(r_barycentric, vec3(0.0)));
235		}
236		
237		const uint RAY_MISS = 0;
238		const uint RAY_FRONT = 1;
239		const uint RAY_BACK = 2;
240		const uint RAY_ANY = 3;
241		
242		bool ray_box_test(vec3 p_from, vec3 p_inv_dir, vec3 p_box_min, vec3 p_box_max) {
243			vec3 t0 = (p_box_min - p_from) * p_inv_dir;
244			vec3 t1 = (p_box_max - p_from) * p_inv_dir;
245			vec3 tmin = min(t0, t1), tmax = max(t0, t1);
246			return max(tmin.x, max(tmin.y, tmin.z)) <= min(tmax.x, min(tmax.y, tmax.z));
247		}
248		
249		#if CLUSTER_SIZE > 32
250		#define CLUSTER_TRIANGLE_ITERATION
251		#endif
252		
253		uint trace_ray(vec3 p_from, vec3 p_to, bool p_any_hit, out float r_distance, out vec3 r_normal, out uint r_triangle, out vec3 r_barycentric) {
254			// World coordinates.
255			vec3 rel = p_to - p_from;
256			float rel_len = length(rel);
257			vec3 dir = normalize(rel);
258			vec3 inv_dir = 1.0 / dir;
259		
260			// Cell coordinates.
261			vec3 from_cell = (p_from - bake_params.to_cell_offset) * bake_params.to_cell_size;
262			vec3 to_cell = (p_to - bake_params.to_cell_offset) * bake_params.to_cell_size;
263		
264			// Prepare DDA.
265			vec3 rel_cell = to_cell - from_cell;
266			ivec3 icell = ivec3(from_cell);
267			ivec3 iendcell = ivec3(to_cell);
268			vec3 dir_cell = normalize(rel_cell);
269			vec3 delta = min(abs(1.0 / dir_cell), bake_params.grid_size); // Use bake_params.grid_size as max to prevent infinity values.
270			ivec3 step = ivec3(sign(rel_cell));
271			vec3 side = (sign(rel_cell) * (vec3(icell) - from_cell) + (sign(rel_cell) * 0.5) + 0.5) * delta;
272		
273			uint iters = 0;
274			while (all(greaterThanEqual(icell, ivec3(0))) && all(lessThan(icell, ivec3(bake_params.grid_size))) && (iters < 1000)) {
275				uvec2 cell_data = texelFetch(usampler3D(grid, linear_sampler), icell, 0).xy;
276				uint triangle_count = cell_data.x;
277				if (triangle_count > 0) {
278					uint hit = RAY_MISS;
279					float best_distance = 1e20;
280					uint cluster_start = cluster_indices.data[cell_data.y * 2];
281					uint cell_triangle_start = cluster_indices.data[cell_data.y * 2 + 1];
282					uint cluster_count = (triangle_count + CLUSTER_SIZE - 1) / CLUSTER_SIZE;
283					uint cluster_base_index = 0;
284					while (cluster_base_index < cluster_count) {
285						// To minimize divergence, all Ray-AABB tests on the clusters contained in the cell are performed
286						// before checking against the triangles. We do this 32 clusters at a time and store the intersected
287						// clusters on each bit of the 32-bit integer.
288						uint cluster_test_count = min(32, cluster_count - cluster_base_index);
289						uint cluster_hits = 0;
290						for (uint i = 0; i < cluster_test_count; i++) {
291							uint cluster_index = cluster_start + cluster_base_index + i;
292							ClusterAABB cluster_aabb = cluster_aabbs.data[cluster_index];
293							if (ray_box_test(p_from, inv_dir, cluster_aabb.min_bounds, cluster_aabb.max_bounds)) {
294								cluster_hits |= (1 << i);
295							}
296						}
297		
298						// Check the triangles in any of the clusters that were intersected by toggling off the bits in the
299						// 32-bit integer counter until no bits are left.
300						while (cluster_hits > 0) {
301							uint cluster_index = findLSB(cluster_hits);
302							cluster_hits &= ~(1 << cluster_index);
303							cluster_index += cluster_base_index;
304		
305							// Do the same divergence execution trick with triangles as well.
306							uint triangle_base_index = 0;
307		#ifdef CLUSTER_TRIANGLE_ITERATION
308							while (triangle_base_index < triangle_count)
309		#endif
310							{
311								uint triangle_start_index = cell_triangle_start + cluster_index * CLUSTER_SIZE + triangle_base_index;
312								uint triangle_test_count = min(CLUSTER_SIZE, triangle_count - triangle_base_index);
313								uint triangle_hits = 0;
314								for (uint i = 0; i < triangle_test_count; i++) {
315									uint triangle_index = triangle_indices.data[triangle_start_index + i];
316									if (ray_box_test(p_from, inv_dir, triangles.data[triangle_index].min_bounds, triangles.data[triangle_index].max_bounds)) {
317										triangle_hits |= (1 << i);
318									}
319								}
320		
321								while (triangle_hits > 0) {
322									uint cluster_triangle_index = findLSB(triangle_hits);
323									triangle_hits &= ~(1 << cluster_triangle_index);
324									cluster_triangle_index += triangle_start_index;
325		
326									uint triangle_index = triangle_indices.data[cluster_triangle_index];
327									Triangle triangle = triangles.data[triangle_index];
328		
329									// Gather the triangle vertex positions.
330									vec3 vtx0 = vertices.data[triangle.indices.x].position;
331									vec3 vtx1 = vertices.data[triangle.indices.y].position;
332									vec3 vtx2 = vertices.data[triangle.indices.z].position;
333									vec3 normal = -normalize(cross((vtx0 - vtx1), (vtx0 - vtx2)));
334									bool backface = dot(normal, dir) >= 0.0;
335									float distance;
336									vec3 barycentric;
337									if (ray_hits_triangle(p_from, dir, rel_len, vtx0, vtx1, vtx2, distance, barycentric)) {
338										if (p_any_hit) {
339											// Return early if any hit was requested.
340											return RAY_ANY;
341										}
342		
343										vec3 position = p_from + dir * distance;
344										vec3 hit_cell = (position - bake_params.to_cell_offset) * bake_params.to_cell_size;
345										if (icell != ivec3(hit_cell)) {
346											// It's possible for the ray to hit a triangle in a position outside the bounds of the cell
347											// if it's large enough to cover multiple ones. The hit must be ignored if this is the case.
348											continue;
349										}
350		
351										if (!backface) {
352											// The case of meshes having both a front and back face in the same plane is more common than
353											// expected, so if this is a front-face, bias it closer to the ray origin, so it always wins
354											// over the back-face.
355											distance = max(bake_params.bias, distance - bake_params.bias);
356										}
357		
358										if (distance < best_distance) {
359											hit = backface ? RAY_BACK : RAY_FRONT;
360											best_distance = distance;
361											r_distance = distance;
362											r_normal = normal;
363											r_triangle = triangle_index;
364											r_barycentric = barycentric;
365										}
366									}
367								}
368		
369		#ifdef CLUSTER_TRIANGLE_ITERATION
370								triangle_base_index += CLUSTER_SIZE;
371		#endif
372							}
373						}
374		
375						cluster_base_index += 32;
376					}
377		
378					if (hit != RAY_MISS) {
379						return hit;
380					}
381				}
382		
383				if (icell == iendcell) {
384					break;
385				}
386		
387				bvec3 mask = lessThanEqual(side.xyz, min(side.yzx, side.zxy));
388				side += vec3(mask) * delta;
389				icell += ivec3(vec3(mask)) * step;
390				iters++;
391			}
392		
393			return RAY_MISS;
394		}
395		
396		uint trace_ray_closest_hit_triangle(vec3 p_from, vec3 p_to, out uint r_triangle, out vec3 r_barycentric) {
397			float distance;
398			vec3 normal;
399			return trace_ray(p_from, p_to, false, distance, normal, r_triangle, r_barycentric);
400		}
401		
402		uint trace_ray_closest_hit_distance(vec3 p_from, vec3 p_to, out float r_distance, out vec3 r_normal) {
403			uint triangle;
404			vec3 barycentric;
405			return trace_ray(p_from, p_to, false, r_distance, r_normal, triangle, barycentric);
406		}
407		
408		uint trace_ray_any_hit(vec3 p_from, vec3 p_to) {
409			float distance;
410			vec3 normal;
411			uint triangle;
412			vec3 barycentric;
413			return trace_ray(p_from, p_to, true, distance, normal, triangle, barycentric);
414		}
415		
416		// https://www.reedbeta.com/blog/hash-functions-for-gpu-rendering/
417		uint hash(uint value) {
418			uint state = value * 747796405u + 2891336453u;
419			uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
420			return (word >> 22u) ^ word;
421		}
422		
423		uint random_seed(ivec3 seed) {
424			return hash(seed.x ^ hash(seed.y ^ hash(seed.z)));
425		}
426		
427		// generates a random value in range [0.0, 1.0)
428		float randomize(inout uint value) {
429			value = hash(value);
430			return float(value / 4294967296.0);
431		}
432		
433		const float PI = 3.14159265f;
434		
435		// http://www.realtimerendering.com/raytracinggems/unofficial_RayTracingGems_v1.4.pdf (chapter 15)
436		vec3 generate_hemisphere_cosine_weighted_direction(inout uint noise) {
437			float noise1 = randomize(noise);
438			float noise2 = randomize(noise) * 2.0 * PI;
439		
440			return vec3(sqrt(noise1) * cos(noise2), sqrt(noise1) * sin(noise2), sqrt(1.0 - noise1));
441		}
442		
443		// Distribution generation adapted from "Generating uniformly distributed numbers on a sphere"
444		// <http://corysimon.github.io/articles/uniformdistn-on-sphere/>
445		vec3 generate_sphere_uniform_direction(inout uint noise) {
446			float theta = 2.0 * PI * randomize(noise);
447			float phi = acos(1.0 - 2.0 * randomize(noise));
448			return vec3(sin(phi) * cos(theta), sin(phi) * sin(theta), cos(phi));
449		}
450		
451		vec3 generate_ray_dir_from_normal(vec3 normal, inout uint noise) {
452			vec3 v0 = abs(normal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
453			vec3 tangent = normalize(cross(v0, normal));
454			vec3 bitangent = normalize(cross(tangent, normal));
455			mat3 normal_mat = mat3(tangent, bitangent, normal);
456			return normal_mat * generate_hemisphere_cosine_weighted_direction(noise);
457		}
458		
459		#if defined(MODE_DIRECT_LIGHT) || defined(MODE_BOUNCE_LIGHT) || defined(MODE_LIGHT_PROBES)
460		
461		float get_omni_attenuation(float distance, float inv_range, float decay) {
462			float nd = distance * inv_range;
463			nd *= nd;
464			nd *= nd; // nd^4
465			nd = max(1.0 - nd, 0.0);
466			nd *= nd; // nd^2
467			return nd * pow(max(distance, 0.0001), -decay);
468		}
469		
470		void trace_direct_light(vec3 p_position, vec3 p_normal, uint p_light_index, bool p_soft_shadowing, out vec3 r_light, out vec3 r_light_dir, inout uint r_noise) {
471			r_light = vec3(0.0f);
472		
473			vec3 light_pos;
474			float dist;
475			float attenuation;
476			float soft_shadowing_disk_size;
477			Light light_data = lights.data[p_light_index];
478			if (light_data.type == LIGHT_TYPE_DIRECTIONAL) {
479				vec3 light_vec = light_data.direction;
480				light_pos = p_position - light_vec * length(bake_params.world_size);
481				r_light_dir = normalize(light_pos - p_position);
482				dist = length(bake_params.world_size);
483				attenuation = 1.0;
484				soft_shadowing_disk_size = light_data.size;
485			} else {
486				light_pos = light_data.position;
487				r_light_dir = normalize(light_pos - p_position);
488				dist = distance(p_position, light_pos);
489				if (dist > light_data.range) {
490					return;
491				}
492		
493				soft_shadowing_disk_size = light_data.size / dist;
494		
495				attenuation = get_omni_attenuation(dist, 1.0 / light_data.range, light_data.attenuation);
496		
497				if (light_data.type == LIGHT_TYPE_SPOT) {
498					vec3 rel = normalize(p_position - light_pos);
499					float cos_spot_angle = light_data.cos_spot_angle;
500					float cos_angle = dot(rel, light_data.direction);
501		
502					if (cos_angle < cos_spot_angle) {
503						return;
504					}
505		
506					float scos = max(cos_angle, cos_spot_angle);
507					float spot_rim = max(0.0001, (1.0 - scos) / (1.0 - cos_spot_angle));
508					attenuation *= 1.0 - pow(spot_rim, light_data.inv_spot_attenuation);
509				}
510			}
511		
512			attenuation *= max(0.0, dot(p_normal, r_light_dir));
513			if (attenuation <= 0.0001) {
514				return;
515			}
516		
517			float penumbra = 0.0;
518			if ((light_data.size > 0.0) && p_soft_shadowing) {
519				vec3 light_to_point = -r_light_dir;
520				vec3 aux = light_to_point.y < 0.777 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
521				vec3 light_to_point_tan = normalize(cross(light_to_point, aux));
522				vec3 light_to_point_bitan = normalize(cross(light_to_point, light_to_point_tan));
523		
524				const uint shadowing_rays_check_penumbra_denom = 2;
525				uint shadowing_ray_count = p_soft_shadowing ? params.ray_count : 1;
526		
527				uint hits = 0;
528				vec3 light_disk_to_point = light_to_point;
529				for (uint j = 0; j < shadowing_ray_count; j++) {
530					// Optimization:
531					// Once already traced an important proportion of rays, if all are hits or misses,
532					// assume we're not in the penumbra so we can infer the rest would have the same result
533					if (p_soft_shadowing) {
534						if (j == shadowing_ray_count / shadowing_rays_check_penumbra_denom) {
535							if (hits == j) {
536								// Assume totally lit
537								hits = shadowing_ray_count;
538								break;
539							} else if (hits == 0) {
540								// Assume totally dark
541								hits = 0;
542								break;
543							}
544						}
545					}
546		
547					float r = randomize(r_noise);
548					float a = randomize(r_noise) * 2.0 * PI;
549					vec2 disk_sample = (r * vec2(cos(a), sin(a))) * soft_shadowing_disk_size * light_data.shadow_blur;
550					light_disk_to_point = normalize(light_to_point + disk_sample.x * light_to_point_tan + disk_sample.y * light_to_point_bitan);
551		
552					if (trace_ray_any_hit(p_position - light_disk_to_point * bake_params.bias, p_position - light_disk_to_point * dist) == RAY_MISS) {
553						hits++;
554					}
555				}
556		
557				penumbra = float(hits) / float(shadowing_ray_count);
558			} else {
559				if (trace_ray_any_hit(p_position + r_light_dir * bake_params.bias, light_pos) == RAY_MISS) {
560					penumbra = 1.0;
561				}
562			}
563		
564			r_light = light_data.color * light_data.energy * attenuation * penumbra;
565		}
566		
567		#endif
568		
569		#if defined(MODE_BOUNCE_LIGHT) || defined(MODE_LIGHT_PROBES)
570		
571		vec3 trace_environment_color(vec3 ray_dir) {
572			vec3 sky_dir = normalize(mat3(bake_params.env_transform) * ray_dir);
573			vec2 st = vec2(atan(sky_dir.x, sky_dir.z), acos(sky_dir.y));
574			if (st.x < 0.0) {
575				st.x += PI * 2.0;
576			}
577		
578			return textureLod(sampler2D(environment, linear_sampler), st / vec2(PI * 2.0, PI), 0.0).rgb;
579		}
580		
581		vec3 trace_indirect_light(vec3 p_position, vec3 p_ray_dir, inout uint r_noise) {
582			// The lower limit considers the case where the lightmapper might have bounces disabled but light probes are requested.
583			vec3 position = p_position;
584			vec3 ray_dir = p_ray_dir;
585			uint max_depth = max(bake_params.bounces, 1);
586			vec3 throughput = vec3(1.0);
587			vec3 light = vec3(0.0);
588			for (uint depth = 0; depth < max_depth; depth++) {
589				uint tidx;
590				vec3 barycentric;
591				uint trace_result = trace_ray_closest_hit_triangle(position + ray_dir * bake_params.bias, position + ray_dir * length(bake_params.world_size), tidx, barycentric);
592				if (trace_result == RAY_FRONT) {
593					Vertex vert0 = vertices.data[triangles.data[tidx].indices.x];
594					Vertex vert1 = vertices.data[triangles.data[tidx].indices.y];
595					Vertex vert2 = vertices.data[triangles.data[tidx].indices.z];
596					vec3 uvw = vec3(barycentric.x * vert0.uv + barycentric.y * vert1.uv + barycentric.z * vert2.uv, float(triangles.data[tidx].slice));
597					position = barycentric.x * vert0.position + barycentric.y * vert1.position + barycentric.z * vert2.position;
598		
599					vec3 norm0 = vec3(vert0.normal_xy, vert0.normal_z);
600					vec3 norm1 = vec3(vert1.normal_xy, vert1.normal_z);
601					vec3 norm2 = vec3(vert2.normal_xy, vert2.normal_z);
602					vec3 normal = barycentric.x * norm0 + barycentric.y * norm1 + barycentric.z * norm2;
603		
604					vec3 direct_light = vec3(0.0f);
605		#ifdef USE_LIGHT_TEXTURE_FOR_BOUNCES
606					direct_light += textureLod(sampler2DArray(source_light, linear_sampler), uvw, 0.0).rgb;
607		#else
608					// Trace the lights directly. Significantly more expensive but more accurate in scenarios
609					// where the lightmap texture isn't reliable.
610					for (uint i = 0; i < bake_params.light_count; i++) {
611						vec3 light;
612						vec3 light_dir;
613						trace_direct_light(position, normal, i, false, light, light_dir, r_noise);
614						direct_light += light * lights.data[i].indirect_energy;
615					}
616		
617					direct_light *= bake_params.exposure_normalization;
618		#endif
619		
620					vec3 albedo = textureLod(sampler2DArray(albedo_tex, linear_sampler), uvw, 0).rgb;
621					vec3 emissive = textureLod(sampler2DArray(emission_tex, linear_sampler), uvw, 0).rgb;
622					emissive *= bake_params.exposure_normalization;
623		
624					light += throughput * emissive;
625					throughput *= albedo;
626					light += throughput * direct_light * bake_params.bounce_indirect_energy;
627		
628					// Use Russian Roulette to determine a probability to terminate the bounce earlier as an optimization.
629					// <https://computergraphics.stackexchange.com/questions/2316/is-russian-roulette-really-the-answer>
630					float p = max(max(throughput.x, throughput.y), throughput.z);
631					if (randomize(r_noise) > p) {
632						break;
633					}
634		
635					// Boost the throughput from the probability of the ray being terminated early.
636					throughput *= 1.0 / p;
637		
638					// Generate a new ray direction for the next bounce from this surface's normal.
639					ray_dir = generate_ray_dir_from_normal(normal, r_noise);
640				} else if (trace_result == RAY_MISS) {
641					// Look for the environment color and stop bouncing.
642					light += throughput * trace_environment_color(ray_dir);
643					break;
644				} else {
645					// Ignore any other trace results.
646					break;
647				}
648			}
649		
650			return light;
651		}
652		
653		#endif
654		
655		void main() {
656			// Check if invocation is out of bounds.
657		#ifdef MODE_LIGHT_PROBES
658			int probe_index = int(gl_GlobalInvocationID.x);
659			if (probe_index >= params.probe_count) {
660				return;
661			}
662		
663		#else
664			ivec2 atlas_pos = ivec2(gl_GlobalInvocationID.xy) + params.region_ofs;
665			if (any(greaterThanEqual(atlas_pos, bake_params.atlas_size))) {
666				return;
667			}
668		#endif
669		
670		#ifdef MODE_DIRECT_LIGHT
671		
672			vec3 normal = texelFetch(sampler2DArray(source_normal, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).xyz;
673			if (length(normal) < 0.5) {
674				return; //empty texel, no process
675			}
676			vec3 position = texelFetch(sampler2DArray(source_position, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).xyz;
677			vec3 light_for_texture = vec3(0.0);
678			vec3 light_for_bounces = vec3(0.0);
679		
680		#ifdef USE_SH_LIGHTMAPS
681			vec4 sh_accum[4] = vec4[](
682					vec4(0.0, 0.0, 0.0, 1.0),
683					vec4(0.0, 0.0, 0.0, 1.0),
684					vec4(0.0, 0.0, 0.0, 1.0),
685					vec4(0.0, 0.0, 0.0, 1.0));
686		#endif
687		
688			// Use atlas position and a prime number as the seed.
689			uint noise = random_seed(ivec3(atlas_pos, 43573547));
690			for (uint i = 0; i < bake_params.light_count; i++) {
691				vec3 light;
692				vec3 light_dir;
693				trace_direct_light(position, normal, i, true, light, light_dir, noise);
694		
695				if (lights.data[i].static_bake) {
696					light_for_texture += light;
697		
698		#ifdef USE_SH_LIGHTMAPS
699					float c[4] = float[](
700							0.282095, //l0
701							0.488603 * light_dir.y, //l1n1
702							0.488603 * light_dir.z, //l1n0
703							0.488603 * light_dir.x //l1p1
704					);
705		
706					for (uint j = 0; j < 4; j++) {
707						sh_accum[j].rgb += light * c[j] * 8.0;
708					}
709		#endif
710				}
711		
712				light_for_bounces += light * lights.data[i].indirect_energy;
713			}
714		
715			light_for_bounces *= bake_params.exposure_normalization;
716			imageStore(dest_light, ivec3(atlas_pos, params.atlas_slice), vec4(light_for_bounces, 1.0));
717		
718		#ifdef USE_SH_LIGHTMAPS
719			// Keep for adding at the end.
720			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + 0), sh_accum[0]);
721			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + 1), sh_accum[1]);
722			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + 2), sh_accum[2]);
723			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + 3), sh_accum[3]);
724		#else
725			light_for_texture *= bake_params.exposure_normalization;
726			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice), vec4(light_for_texture, 1.0));
727		#endif
728		
729		#endif
730		
731		#ifdef MODE_BOUNCE_LIGHT
732		
733		#ifdef USE_SH_LIGHTMAPS
734			vec4 sh_accum[4] = vec4[](
735					vec4(0.0, 0.0, 0.0, 1.0),
736					vec4(0.0, 0.0, 0.0, 1.0),
737					vec4(0.0, 0.0, 0.0, 1.0),
738					vec4(0.0, 0.0, 0.0, 1.0));
739		#else
740			vec3 light_accum = vec3(0.0);
741		#endif
742		
743			// Retrieve starting normal and position.
744			vec3 normal = texelFetch(sampler2DArray(source_normal, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).xyz;
745			if (length(normal) < 0.5) {
746				// The pixel is empty, skip processing it.
747				return;
748			}
749		
750			vec3 position = texelFetch(sampler2DArray(source_position, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).xyz;
751			uint noise = random_seed(ivec3(params.ray_from, atlas_pos));
752			for (uint i = params.ray_from; i < params.ray_to; i++) {
753				vec3 ray_dir = generate_ray_dir_from_normal(normal, noise);
754				vec3 light = trace_indirect_light(position, ray_dir, noise);
755		
756		#ifdef USE_SH_LIGHTMAPS
757				float c[4] = float[](
758						0.282095, //l0
759						0.488603 * ray_dir.y, //l1n1
760						0.488603 * ray_dir.z, //l1n0
761						0.488603 * ray_dir.x //l1p1
762				);
763		
764				for (uint j = 0; j < 4; j++) {
765					sh_accum[j].rgb += light * c[j] * 8.0;
766				}
767		#else
768				light_accum += light;
769		#endif
770			}
771		
772			// Add the averaged result to the accumulated light texture.
773		#ifdef USE_SH_LIGHTMAPS
774			for (int i = 0; i < 4; i++) {
775				vec4 accum = imageLoad(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + i));
776				accum.rgb += sh_accum[i].rgb / float(params.ray_count);
777				imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + i), accum);
778			}
779		#else
780			vec4 accum = imageLoad(accum_light, ivec3(atlas_pos, params.atlas_slice));
781			accum.rgb += light_accum / float(params.ray_count);
782			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice), accum);
783		#endif
784		
785		#endif
786		
787		#ifdef MODE_UNOCCLUDE
788		
789			//texel_size = 0.5;
790			//compute tangents
791		
792			vec4 position_alpha = imageLoad(position, ivec3(atlas_pos, params.atlas_slice));
793			if (position_alpha.a < 0.5) {
794				return;
795			}
796		
797			vec3 vertex_pos = position_alpha.xyz;
798			vec4 normal_tsize = imageLoad(unocclude, ivec3(atlas_pos, params.atlas_slice));
799		
800			vec3 face_normal = normal_tsize.xyz;
801			float texel_size = normal_tsize.w;
802		
803			vec3 v0 = abs(face_normal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
804			vec3 tangent = normalize(cross(v0, face_normal));
805			vec3 bitangent = normalize(cross(tangent, face_normal));
806			vec3 base_pos = vertex_pos + face_normal * bake_params.bias; // Raise a bit.
807		
808			vec3 rays[4] = vec3[](tangent, bitangent, -tangent, -bitangent);
809			float min_d = 1e20;
810			for (int i = 0; i < 4; i++) {
811				vec3 ray_to = base_pos + rays[i] * texel_size;
812				float d;
813				vec3 norm;
814		
815				if (trace_ray_closest_hit_distance(base_pos, ray_to, d, norm) == RAY_BACK) {
816					if (d < min_d) {
817						// This bias needs to be greater than the regular bias, because otherwise later, rays will go the other side when pointing back.
818						vertex_pos = base_pos + rays[i] * d + norm * bake_params.bias * 10.0;
819						min_d = d;
820					}
821				}
822			}
823		
824			position_alpha.xyz = vertex_pos;
825		
826			imageStore(position, ivec3(atlas_pos, params.atlas_slice), position_alpha);
827		
828		#endif
829		
830		#ifdef MODE_LIGHT_PROBES
831		
832			vec3 position = probe_positions.data[probe_index].xyz;
833		
834			vec4 probe_sh_accum[9] = vec4[](
835					vec4(0.0),
836					vec4(0.0),
837					vec4(0.0),
838					vec4(0.0),
839					vec4(0.0),
840					vec4(0.0),
841					vec4(0.0),
842					vec4(0.0),
843					vec4(0.0));
844		
845			uint noise = random_seed(ivec3(params.ray_from, probe_index, 49502741 /* some prime */));
846			for (uint i = params.ray_from; i < params.ray_to; i++) {
847				vec3 ray_dir = generate_sphere_uniform_direction(noise);
848				vec3 light = trace_indirect_light(position, ray_dir, noise);
849		
850				float c[9] = float[](
851						0.282095, //l0
852						0.488603 * ray_dir.y, //l1n1
853						0.488603 * ray_dir.z, //l1n0
854						0.488603 * ray_dir.x, //l1p1
855						1.092548 * ray_dir.x * ray_dir.y, //l2n2
856						1.092548 * ray_dir.y * ray_dir.z, //l2n1
857						//0.315392 * (ray_dir.x * ray_dir.x + ray_dir.y * ray_dir.y + 2.0 * ray_dir.z * ray_dir.z), //l20
858						0.315392 * (3.0 * ray_dir.z * ray_dir.z - 1.0), //l20
859						1.092548 * ray_dir.x * ray_dir.z, //l2p1
860						0.546274 * (ray_dir.x * ray_dir.x - ray_dir.y * ray_dir.y) //l2p2
861				);
862		
863				for (uint j = 0; j < 9; j++) {
864					probe_sh_accum[j].rgb += light * c[j];
865				}
866			}
867		
868			if (params.ray_from > 0) {
869				for (uint j = 0; j < 9; j++) { //accum from existing
870					probe_sh_accum[j] += light_probes.data[probe_index * 9 + j];
871				}
872			}
873		
874			if (params.ray_to == params.ray_count) {
875				for (uint j = 0; j < 9; j++) { //accum from existing
876					probe_sh_accum[j] *= 4.0 / float(params.ray_count);
877				}
878			}
879		
880			for (uint j = 0; j < 9; j++) { //accum from existing
881				light_probes.data[probe_index * 9 + j] = probe_sh_accum[j];
882			}
883		
884		#endif
885		
886		#ifdef MODE_DILATE
887		
888			vec4 c = texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0);
889			//sides first, as they are closer
890			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-1, 0), params.atlas_slice), 0);
891			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(0, 1), params.atlas_slice), 0);
892			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(1, 0), params.atlas_slice), 0);
893			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(0, -1), params.atlas_slice), 0);
894			//endpoints second
895			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-1, -1), params.atlas_slice), 0);
896			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-1, 1), params.atlas_slice), 0);
897			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(1, -1), params.atlas_slice), 0);
898			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(1, 1), params.atlas_slice), 0);
899		
900			//far sides third
901			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-2, 0), params.atlas_slice), 0);
902			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(0, 2), params.atlas_slice), 0);
903			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(2, 0), params.atlas_slice), 0);
904			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(0, -2), params.atlas_slice), 0);
905		
906			//far-mid endpoints
907			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-2, -1), params.atlas_slice), 0);
908			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-2, 1), params.atlas_slice), 0);
909			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(2, -1), params.atlas_slice), 0);
910			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(2, 1), params.atlas_slice), 0);
911		
912			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-1, -2), params.atlas_slice), 0);
913			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-1, 2), params.atlas_slice), 0);
914			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(1, -2), params.atlas_slice), 0);
915			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(1, 2), params.atlas_slice), 0);
916			//far endpoints
917			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-2, -2), params.atlas_slice), 0);
918			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-2, 2), params.atlas_slice), 0);
919			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(2, -2), params.atlas_slice), 0);
920			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(2, 2), params.atlas_slice), 0);
921		
922			imageStore(dest_light, ivec3(atlas_pos, params.atlas_slice), c);
923		
924		#endif
925		
926		#ifdef MODE_DENOISE
927			// Joint Non-local means (JNLM) denoiser.
928			//
929			// Based on YoctoImageDenoiser's JNLM implementation with corrections from "Nonlinearly Weighted First-order Regression for Denoising Monte Carlo Renderings".
930			//
931			// <https://github.com/ManuelPrandini/YoctoImageDenoiser/blob/06e19489dd64e47792acffde536393802ba48607/libs/yocto_extension/yocto_extension.cpp#L207>
932			// <https://benedikt-bitterli.me/nfor/nfor.pdf>
933			//
934			// MIT License
935			//
936			// Copyright (c) 2020 ManuelPrandini
937			//
938			// Permission is hereby granted, free of charge, to any person obtaining a copy
939			// of this software and associated documentation files (the "Software"), to deal
940			// in the Software without restriction, including without limitation the rights
941			// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
942			// copies of the Software, and to permit persons to whom the Software is
943			// furnished to do so, subject to the following conditions:
944			//
945			// The above copyright notice and this permission notice shall be included in all
946			// copies or substantial portions of the Software.
947			//
948			// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
949			// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
950			// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
951			// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
952			// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
953			// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
954			// SOFTWARE.
955			//
956			// Most of the constants below have been hand-picked to fit the common scenarios lightmaps
957			// are generated with, but they can be altered freely to experiment and achieve better results.
958		
959			// Half the size of the patch window around each pixel that is weighted to compute the denoised pixel.
960			// A value of 1 represents a 3x3 window, a value of 2 a 5x5 window, etc.
961			const int HALF_PATCH_WINDOW = 4;
962		
963			// Half the size of the search window around each pixel that is denoised and weighted to compute the denoised pixel.
964			const int HALF_SEARCH_WINDOW = 10;
965		
966			// For all of the following sigma values, smaller values will give less weight to pixels that have a bigger distance
967			// in the feature being evaluated. Therefore, smaller values are likely to cause more noise to appear, but will also
968			// cause less features to be erased in the process.
969		
970			// Controls how much the spatial distance of the pixels influences the denoising weight.
971			const float SIGMA_SPATIAL = denoise_params.spatial_bandwidth;
972		
973			// Controls how much the light color distance of the pixels influences the denoising weight.
974			const float SIGMA_LIGHT = denoise_params.light_bandwidth;
975		
976			// Controls how much the albedo color distance of the pixels influences the denoising weight.
977			const float SIGMA_ALBEDO = denoise_params.albedo_bandwidth;
978		
979			// Controls how much the normal vector distance of the pixels influences the denoising weight.
980			const float SIGMA_NORMAL = denoise_params.normal_bandwidth;
981		
982			// Strength of the filter. The original paper recommends values around 10 to 15 times the Sigma parameter.
983			const float FILTER_VALUE = denoise_params.filter_strength * SIGMA_LIGHT;
984		
985			// Formula constants.
986			const int PATCH_WINDOW_DIMENSION = (HALF_PATCH_WINDOW * 2 + 1);
987			const int PATCH_WINDOW_DIMENSION_SQUARE = (PATCH_WINDOW_DIMENSION * PATCH_WINDOW_DIMENSION);
988			const float TWO_SIGMA_SPATIAL_SQUARE = 2.0f * SIGMA_SPATIAL * SIGMA_SPATIAL;
989			const float TWO_SIGMA_LIGHT_SQUARE = 2.0f * SIGMA_LIGHT * SIGMA_LIGHT;
990			const float TWO_SIGMA_ALBEDO_SQUARE = 2.0f * SIGMA_ALBEDO * SIGMA_ALBEDO;
991			const float TWO_SIGMA_NORMAL_SQUARE = 2.0f * SIGMA_NORMAL * SIGMA_NORMAL;
992			const float FILTER_SQUARE_TWO_SIGMA_LIGHT_SQUARE = FILTER_VALUE * FILTER_VALUE * TWO_SIGMA_LIGHT_SQUARE;
993			const float EPSILON = 1e-6f;
994		
995		#ifdef USE_SH_LIGHTMAPS
996			const uint slice_count = 4;
997			const uint slice_base = params.atlas_slice * slice_count;
998		#else
999			const uint slice_count = 1;
1000			const uint slice_base = params.atlas_slice;
1001		#endif
1002		
1003			for (uint i = 0; i < slice_count; i++) {
1004				uint lightmap_slice = slice_base + i;
1005				vec3 denoised_rgb = vec3(0.0f);
1006				vec4 input_light = texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos, lightmap_slice), 0);
1007				vec3 input_albedo = texelFetch(sampler2DArray(albedo_tex, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).rgb;
1008				vec3 input_normal = texelFetch(sampler2DArray(source_normal, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).xyz;
1009				if (length(input_normal) > EPSILON) {
1010					// Compute the denoised pixel if the normal is valid.
1011					float sum_weights = 0.0f;
1012					vec3 input_rgb = input_light.rgb;
1013					for (int search_y = -HALF_SEARCH_WINDOW; search_y <= HALF_SEARCH_WINDOW; search_y++) {
1014						for (int search_x = -HALF_SEARCH_WINDOW; search_x <= HALF_SEARCH_WINDOW; search_x++) {
1015							ivec2 search_pos = atlas_pos + ivec2(search_x, search_y);
1016							vec3 search_rgb = texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(search_pos, lightmap_slice), 0).rgb;
1017							vec3 search_albedo = texelFetch(sampler2DArray(albedo_tex, linear_sampler), ivec3(search_pos, params.atlas_slice), 0).rgb;
1018							vec3 search_normal = texelFetch(sampler2DArray(source_normal, linear_sampler), ivec3(search_pos, params.atlas_slice), 0).xyz;
1019							float patch_square_dist = 0.0f;
1020							for (int offset_y = -HALF_PATCH_WINDOW; offset_y <= HALF_PATCH_WINDOW; offset_y++) {
1021								for (int offset_x = -HALF_PATCH_WINDOW; offset_x <= HALF_PATCH_WINDOW; offset_x++) {
1022									ivec2 offset_input_pos = atlas_pos + ivec2(offset_x, offset_y);
1023									ivec2 offset_search_pos = search_pos + ivec2(offset_x, offset_y);
1024									vec3 offset_input_rgb = texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(offset_input_pos, lightmap_slice), 0).rgb;
1025									vec3 offset_search_rgb = texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(offset_search_pos, lightmap_slice), 0).rgb;
1026									vec3 offset_delta_rgb = offset_input_rgb - offset_search_rgb;
1027									patch_square_dist += dot(offset_delta_rgb, offset_delta_rgb) - TWO_SIGMA_LIGHT_SQUARE;
1028								}
1029							}
1030		
1031							patch_square_dist = max(0.0f, patch_square_dist / (3.0f * PATCH_WINDOW_DIMENSION_SQUARE));
1032		
1033							float weight = 1.0f;
1034		
1035							// Ignore weight if search position is out of bounds.
1036							weight *= step(0, search_pos.x) * step(search_pos.x, bake_params.atlas_size.x - 1);
1037							weight *= step(0, search_pos.y) * step(search_pos.y, bake_params.atlas_size.y - 1);
1038		
1039							// Ignore weight if normal is zero length.
1040							weight *= step(EPSILON, length(search_normal));
1041		
1042							// Weight with pixel distance.
1043							vec2 pixel_delta = vec2(search_x, search_y);
1044							float pixel_square_dist = dot(pixel_delta, pixel_delta);
1045							weight *= exp(-pixel_square_dist / TWO_SIGMA_SPATIAL_SQUARE);
1046		
1047							// Weight with patch.
1048							weight *= exp(-patch_square_dist / FILTER_SQUARE_TWO_SIGMA_LIGHT_SQUARE);
1049		
1050							// Weight with albedo.
1051							vec3 albedo_delta = input_albedo - search_albedo;
1052							float albedo_square_dist = dot(albedo_delta, albedo_delta);
1053							weight *= exp(-albedo_square_dist / TWO_SIGMA_ALBEDO_SQUARE);
1054		
1055							// Weight with normal.
1056							vec3 normal_delta = input_normal - search_normal;
1057							float normal_square_dist = dot(normal_delta, normal_delta);
1058							weight *= exp(-normal_square_dist / TWO_SIGMA_NORMAL_SQUARE);
1059		
1060							denoised_rgb += weight * search_rgb;
1061							sum_weights += weight;
1062						}
1063					}
1064		
1065					denoised_rgb /= sum_weights;
1066				} else {
1067					// Ignore pixels where the normal is empty, just copy the light color.
1068					denoised_rgb = input_light.rgb;
1069				}
1070		
1071				imageStore(dest_light, ivec3(atlas_pos, lightmap_slice), vec4(denoised_rgb, input_light.a));
1072			}
1073		#endif
1074		}
1075		
1076		
          RDShaderSPIRV          ­  Failed parse:
ERROR: 0:282: 'CLUSTER_SIZE' : undeclared identifier 
ERROR: 0:282: '' : compilation terminated 
ERROR: 2 compilation errors.  No code generated.




Stage 'compute' source code: 

1		
2		#version 450
3		
4		#
5		#define MODE_UNOCCLUDE
6		
7		
8		
9		// One 2D local group focusing in one layer at a time, though all
10		// in parallel (no barriers) makes more sense than a 3D local group
11		// as this can take more advantage of the cache for each group.
12		
13		#ifdef MODE_LIGHT_PROBES
14		
15		layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
16		
17		#else
18		
19		layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
20		
21		#endif
22		
23		
24		
25		/* SET 0, static data that does not change between any call */
26		
27		layout(set = 0, binding = 0) uniform BakeParameters {
28			vec3 world_size;
29			float bias;
30		
31			vec3 to_cell_offset;
32			int grid_size;
33		
34			vec3 to_cell_size;
35			uint light_count;
36		
37			mat3x4 env_transform;
38		
39			ivec2 atlas_size;
40			float exposure_normalization;
41			uint bounces;
42		
43			float bounce_indirect_energy;
44		}
45		bake_params;
46		
47		struct Vertex {
48			vec3 position;
49			float normal_z;
50			vec2 uv;
51			vec2 normal_xy;
52		};
53		
54		layout(set = 0, binding = 1, std430) restrict readonly buffer Vertices {
55			Vertex data[];
56		}
57		vertices;
58		
59		struct Triangle {
60			uvec3 indices;
61			uint slice;
62			vec3 min_bounds;
63			uint pad0;
64			vec3 max_bounds;
65			uint pad1;
66		};
67		
68		struct ClusterAABB {
69			vec3 min_bounds;
70			uint pad0;
71			vec3 max_bounds;
72			uint pad1;
73		};
74		
75		layout(set = 0, binding = 2, std430) restrict readonly buffer Triangles {
76			Triangle data[];
77		}
78		triangles;
79		
80		layout(set = 0, binding = 3, std430) restrict readonly buffer TriangleIndices {
81			uint data[];
82		}
83		triangle_indices;
84		
85		#define LIGHT_TYPE_DIRECTIONAL 0
86		#define LIGHT_TYPE_OMNI 1
87		#define LIGHT_TYPE_SPOT 2
88		
89		struct Light {
90			vec3 position;
91			uint type;
92		
93			vec3 direction;
94			float energy;
95		
96			vec3 color;
97			float size;
98		
99			float range;
100			float attenuation;
101			float cos_spot_angle;
102			float inv_spot_attenuation;
103		
104			float indirect_energy;
105			float shadow_blur;
106			bool static_bake;
107			uint pad;
108		};
109		
110		layout(set = 0, binding = 4, std430) restrict readonly buffer Lights {
111			Light data[];
112		}
113		lights;
114		
115		struct Seam {
116			uvec2 a;
117			uvec2 b;
118		};
119		
120		layout(set = 0, binding = 5, std430) restrict readonly buffer Seams {
121			Seam data[];
122		}
123		seams;
124		
125		layout(set = 0, binding = 6, std430) restrict readonly buffer Probes {
126			vec4 data[];
127		}
128		probe_positions;
129		
130		layout(set = 0, binding = 7) uniform utexture3D grid;
131		
132		layout(set = 0, binding = 8) uniform texture2DArray albedo_tex;
133		layout(set = 0, binding = 9) uniform texture2DArray emission_tex;
134		
135		layout(set = 0, binding = 10) uniform sampler linear_sampler;
136		
137		layout(set = 0, binding = 11, std430) restrict readonly buffer ClusterIndices {
138			uint data[];
139		}
140		cluster_indices;
141		
142		layout(set = 0, binding = 12, std430) restrict readonly buffer ClusterAABBs {
143			ClusterAABB data[];
144		}
145		cluster_aabbs;
146		
147		// Fragment action constants
148		const uint FA_NONE = 0;
149		const uint FA_SMOOTHEN_POSITION = 1;
150		
151		
152		#ifdef MODE_LIGHT_PROBES
153		
154		layout(set = 1, binding = 0, std430) restrict buffer LightProbeData {
155			vec4 data[];
156		}
157		light_probes;
158		
159		layout(set = 1, binding = 1) uniform texture2DArray source_light;
160		layout(set = 1, binding = 2) uniform texture2D environment;
161		#endif
162		
163		#ifdef MODE_UNOCCLUDE
164		
165		layout(rgba32f, set = 1, binding = 0) uniform restrict image2DArray position;
166		layout(rgba32f, set = 1, binding = 1) uniform restrict readonly image2DArray unocclude;
167		
168		#endif
169		
170		#if defined(MODE_DIRECT_LIGHT) || defined(MODE_BOUNCE_LIGHT)
171		
172		layout(rgba16f, set = 1, binding = 0) uniform restrict writeonly image2DArray dest_light;
173		layout(set = 1, binding = 1) uniform texture2DArray source_light;
174		layout(set = 1, binding = 2) uniform texture2DArray source_position;
175		layout(set = 1, binding = 3) uniform texture2DArray source_normal;
176		layout(rgba16f, set = 1, binding = 4) uniform restrict image2DArray accum_light;
177		
178		#endif
179		
180		#ifdef MODE_BOUNCE_LIGHT
181		layout(set = 1, binding = 5) uniform texture2D environment;
182		#endif
183		
184		#if defined(MODE_DILATE) || defined(MODE_DENOISE)
185		layout(rgba16f, set = 1, binding = 0) uniform restrict writeonly image2DArray dest_light;
186		layout(set = 1, binding = 1) uniform texture2DArray source_light;
187		#endif
188		
189		#ifdef MODE_DENOISE
190		layout(set = 1, binding = 2) uniform texture2DArray source_normal;
191		layout(set = 1, binding = 3) uniform DenoiseParams {
192			float spatial_bandwidth;
193			float light_bandwidth;
194			float albedo_bandwidth;
195			float normal_bandwidth;
196		
197			float filter_strength;
198		}
199		denoise_params;
200		#endif
201		
202		layout(push_constant, std430) uniform Params {
203			uint atlas_slice;
204			uint ray_count;
205			uint ray_from;
206			uint ray_to;
207		
208			ivec2 region_ofs;
209			uint probe_count;
210		}
211		params;
212		
213		//check it, but also return distance and barycentric coords (for uv lookup)
214		bool ray_hits_triangle(vec3 from, vec3 dir, float max_dist, vec3 p0, vec3 p1, vec3 p2, out float r_distance, out vec3 r_barycentric) {
215			const float EPSILON = 0.00001;
216			const vec3 e0 = p1 - p0;
217			const vec3 e1 = p0 - p2;
218			vec3 triangle_normal = cross(e1, e0);
219		
220			float n_dot_dir = dot(triangle_normal, dir);
221		
222			if (abs(n_dot_dir) < EPSILON) {
223				return false;
224			}
225		
226			const vec3 e2 = (p0 - from) / n_dot_dir;
227			const vec3 i = cross(dir, e2);
228		
229			r_barycentric.y = dot(i, e1);
230			r_barycentric.z = dot(i, e0);
231			r_barycentric.x = 1.0 - (r_barycentric.z + r_barycentric.y);
232			r_distance = dot(triangle_normal, e2);
233		
234			return (r_distance > bake_params.bias) && (r_distance < max_dist) && all(greaterThanEqual(r_barycentric, vec3(0.0)));
235		}
236		
237		const uint RAY_MISS = 0;
238		const uint RAY_FRONT = 1;
239		const uint RAY_BACK = 2;
240		const uint RAY_ANY = 3;
241		
242		bool ray_box_test(vec3 p_from, vec3 p_inv_dir, vec3 p_box_min, vec3 p_box_max) {
243			vec3 t0 = (p_box_min - p_from) * p_inv_dir;
244			vec3 t1 = (p_box_max - p_from) * p_inv_dir;
245			vec3 tmin = min(t0, t1), tmax = max(t0, t1);
246			return max(tmin.x, max(tmin.y, tmin.z)) <= min(tmax.x, min(tmax.y, tmax.z));
247		}
248		
249		#if CLUSTER_SIZE > 32
250		#define CLUSTER_TRIANGLE_ITERATION
251		#endif
252		
253		uint trace_ray(vec3 p_from, vec3 p_to, bool p_any_hit, out float r_distance, out vec3 r_normal, out uint r_triangle, out vec3 r_barycentric) {
254			// World coordinates.
255			vec3 rel = p_to - p_from;
256			float rel_len = length(rel);
257			vec3 dir = normalize(rel);
258			vec3 inv_dir = 1.0 / dir;
259		
260			// Cell coordinates.
261			vec3 from_cell = (p_from - bake_params.to_cell_offset) * bake_params.to_cell_size;
262			vec3 to_cell = (p_to - bake_params.to_cell_offset) * bake_params.to_cell_size;
263		
264			// Prepare DDA.
265			vec3 rel_cell = to_cell - from_cell;
266			ivec3 icell = ivec3(from_cell);
267			ivec3 iendcell = ivec3(to_cell);
268			vec3 dir_cell = normalize(rel_cell);
269			vec3 delta = min(abs(1.0 / dir_cell), bake_params.grid_size); // Use bake_params.grid_size as max to prevent infinity values.
270			ivec3 step = ivec3(sign(rel_cell));
271			vec3 side = (sign(rel_cell) * (vec3(icell) - from_cell) + (sign(rel_cell) * 0.5) + 0.5) * delta;
272		
273			uint iters = 0;
274			while (all(greaterThanEqual(icell, ivec3(0))) && all(lessThan(icell, ivec3(bake_params.grid_size))) && (iters < 1000)) {
275				uvec2 cell_data = texelFetch(usampler3D(grid, linear_sampler), icell, 0).xy;
276				uint triangle_count = cell_data.x;
277				if (triangle_count > 0) {
278					uint hit = RAY_MISS;
279					float best_distance = 1e20;
280					uint cluster_start = cluster_indices.data[cell_data.y * 2];
281					uint cell_triangle_start = cluster_indices.data[cell_data.y * 2 + 1];
282					uint cluster_count = (triangle_count + CLUSTER_SIZE - 1) / CLUSTER_SIZE;
283					uint cluster_base_index = 0;
284					while (cluster_base_index < cluster_count) {
285						// To minimize divergence, all Ray-AABB tests on the clusters contained in the cell are performed
286						// before checking against the triangles. We do this 32 clusters at a time and store the intersected
287						// clusters on each bit of the 32-bit integer.
288						uint cluster_test_count = min(32, cluster_count - cluster_base_index);
289						uint cluster_hits = 0;
290						for (uint i = 0; i < cluster_test_count; i++) {
291							uint cluster_index = cluster_start + cluster_base_index + i;
292							ClusterAABB cluster_aabb = cluster_aabbs.data[cluster_index];
293							if (ray_box_test(p_from, inv_dir, cluster_aabb.min_bounds, cluster_aabb.max_bounds)) {
294								cluster_hits |= (1 << i);
295							}
296						}
297		
298						// Check the triangles in any of the clusters that were intersected by toggling off the bits in the
299						// 32-bit integer counter until no bits are left.
300						while (cluster_hits > 0) {
301							uint cluster_index = findLSB(cluster_hits);
302							cluster_hits &= ~(1 << cluster_index);
303							cluster_index += cluster_base_index;
304		
305							// Do the same divergence execution trick with triangles as well.
306							uint triangle_base_index = 0;
307		#ifdef CLUSTER_TRIANGLE_ITERATION
308							while (triangle_base_index < triangle_count)
309		#endif
310							{
311								uint triangle_start_index = cell_triangle_start + cluster_index * CLUSTER_SIZE + triangle_base_index;
312								uint triangle_test_count = min(CLUSTER_SIZE, triangle_count - triangle_base_index);
313								uint triangle_hits = 0;
314								for (uint i = 0; i < triangle_test_count; i++) {
315									uint triangle_index = triangle_indices.data[triangle_start_index + i];
316									if (ray_box_test(p_from, inv_dir, triangles.data[triangle_index].min_bounds, triangles.data[triangle_index].max_bounds)) {
317										triangle_hits |= (1 << i);
318									}
319								}
320		
321								while (triangle_hits > 0) {
322									uint cluster_triangle_index = findLSB(triangle_hits);
323									triangle_hits &= ~(1 << cluster_triangle_index);
324									cluster_triangle_index += triangle_start_index;
325		
326									uint triangle_index = triangle_indices.data[cluster_triangle_index];
327									Triangle triangle = triangles.data[triangle_index];
328		
329									// Gather the triangle vertex positions.
330									vec3 vtx0 = vertices.data[triangle.indices.x].position;
331									vec3 vtx1 = vertices.data[triangle.indices.y].position;
332									vec3 vtx2 = vertices.data[triangle.indices.z].position;
333									vec3 normal = -normalize(cross((vtx0 - vtx1), (vtx0 - vtx2)));
334									bool backface = dot(normal, dir) >= 0.0;
335									float distance;
336									vec3 barycentric;
337									if (ray_hits_triangle(p_from, dir, rel_len, vtx0, vtx1, vtx2, distance, barycentric)) {
338										if (p_any_hit) {
339											// Return early if any hit was requested.
340											return RAY_ANY;
341										}
342		
343										vec3 position = p_from + dir * distance;
344										vec3 hit_cell = (position - bake_params.to_cell_offset) * bake_params.to_cell_size;
345										if (icell != ivec3(hit_cell)) {
346											// It's possible for the ray to hit a triangle in a position outside the bounds of the cell
347											// if it's large enough to cover multiple ones. The hit must be ignored if this is the case.
348											continue;
349										}
350		
351										if (!backface) {
352											// The case of meshes having both a front and back face in the same plane is more common than
353											// expected, so if this is a front-face, bias it closer to the ray origin, so it always wins
354											// over the back-face.
355											distance = max(bake_params.bias, distance - bake_params.bias);
356										}
357		
358										if (distance < best_distance) {
359											hit = backface ? RAY_BACK : RAY_FRONT;
360											best_distance = distance;
361											r_distance = distance;
362											r_normal = normal;
363											r_triangle = triangle_index;
364											r_barycentric = barycentric;
365										}
366									}
367								}
368		
369		#ifdef CLUSTER_TRIANGLE_ITERATION
370								triangle_base_index += CLUSTER_SIZE;
371		#endif
372							}
373						}
374		
375						cluster_base_index += 32;
376					}
377		
378					if (hit != RAY_MISS) {
379						return hit;
380					}
381				}
382		
383				if (icell == iendcell) {
384					break;
385				}
386		
387				bvec3 mask = lessThanEqual(side.xyz, min(side.yzx, side.zxy));
388				side += vec3(mask) * delta;
389				icell += ivec3(vec3(mask)) * step;
390				iters++;
391			}
392		
393			return RAY_MISS;
394		}
395		
396		uint trace_ray_closest_hit_triangle(vec3 p_from, vec3 p_to, out uint r_triangle, out vec3 r_barycentric) {
397			float distance;
398			vec3 normal;
399			return trace_ray(p_from, p_to, false, distance, normal, r_triangle, r_barycentric);
400		}
401		
402		uint trace_ray_closest_hit_distance(vec3 p_from, vec3 p_to, out float r_distance, out vec3 r_normal) {
403			uint triangle;
404			vec3 barycentric;
405			return trace_ray(p_from, p_to, false, r_distance, r_normal, triangle, barycentric);
406		}
407		
408		uint trace_ray_any_hit(vec3 p_from, vec3 p_to) {
409			float distance;
410			vec3 normal;
411			uint triangle;
412			vec3 barycentric;
413			return trace_ray(p_from, p_to, true, distance, normal, triangle, barycentric);
414		}
415		
416		// https://www.reedbeta.com/blog/hash-functions-for-gpu-rendering/
417		uint hash(uint value) {
418			uint state = value * 747796405u + 2891336453u;
419			uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
420			return (word >> 22u) ^ word;
421		}
422		
423		uint random_seed(ivec3 seed) {
424			return hash(seed.x ^ hash(seed.y ^ hash(seed.z)));
425		}
426		
427		// generates a random value in range [0.0, 1.0)
428		float randomize(inout uint value) {
429			value = hash(value);
430			return float(value / 4294967296.0);
431		}
432		
433		const float PI = 3.14159265f;
434		
435		// http://www.realtimerendering.com/raytracinggems/unofficial_RayTracingGems_v1.4.pdf (chapter 15)
436		vec3 generate_hemisphere_cosine_weighted_direction(inout uint noise) {
437			float noise1 = randomize(noise);
438			float noise2 = randomize(noise) * 2.0 * PI;
439		
440			return vec3(sqrt(noise1) * cos(noise2), sqrt(noise1) * sin(noise2), sqrt(1.0 - noise1));
441		}
442		
443		// Distribution generation adapted from "Generating uniformly distributed numbers on a sphere"
444		// <http://corysimon.github.io/articles/uniformdistn-on-sphere/>
445		vec3 generate_sphere_uniform_direction(inout uint noise) {
446			float theta = 2.0 * PI * randomize(noise);
447			float phi = acos(1.0 - 2.0 * randomize(noise));
448			return vec3(sin(phi) * cos(theta), sin(phi) * sin(theta), cos(phi));
449		}
450		
451		vec3 generate_ray_dir_from_normal(vec3 normal, inout uint noise) {
452			vec3 v0 = abs(normal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
453			vec3 tangent = normalize(cross(v0, normal));
454			vec3 bitangent = normalize(cross(tangent, normal));
455			mat3 normal_mat = mat3(tangent, bitangent, normal);
456			return normal_mat * generate_hemisphere_cosine_weighted_direction(noise);
457		}
458		
459		#if defined(MODE_DIRECT_LIGHT) || defined(MODE_BOUNCE_LIGHT) || defined(MODE_LIGHT_PROBES)
460		
461		float get_omni_attenuation(float distance, float inv_range, float decay) {
462			float nd = distance * inv_range;
463			nd *= nd;
464			nd *= nd; // nd^4
465			nd = max(1.0 - nd, 0.0);
466			nd *= nd; // nd^2
467			return nd * pow(max(distance, 0.0001), -decay);
468		}
469		
470		void trace_direct_light(vec3 p_position, vec3 p_normal, uint p_light_index, bool p_soft_shadowing, out vec3 r_light, out vec3 r_light_dir, inout uint r_noise) {
471			r_light = vec3(0.0f);
472		
473			vec3 light_pos;
474			float dist;
475			float attenuation;
476			float soft_shadowing_disk_size;
477			Light light_data = lights.data[p_light_index];
478			if (light_data.type == LIGHT_TYPE_DIRECTIONAL) {
479				vec3 light_vec = light_data.direction;
480				light_pos = p_position - light_vec * length(bake_params.world_size);
481				r_light_dir = normalize(light_pos - p_position);
482				dist = length(bake_params.world_size);
483				attenuation = 1.0;
484				soft_shadowing_disk_size = light_data.size;
485			} else {
486				light_pos = light_data.position;
487				r_light_dir = normalize(light_pos - p_position);
488				dist = distance(p_position, light_pos);
489				if (dist > light_data.range) {
490					return;
491				}
492		
493				soft_shadowing_disk_size = light_data.size / dist;
494		
495				attenuation = get_omni_attenuation(dist, 1.0 / light_data.range, light_data.attenuation);
496		
497				if (light_data.type == LIGHT_TYPE_SPOT) {
498					vec3 rel = normalize(p_position - light_pos);
499					float cos_spot_angle = light_data.cos_spot_angle;
500					float cos_angle = dot(rel, light_data.direction);
501		
502					if (cos_angle < cos_spot_angle) {
503						return;
504					}
505		
506					float scos = max(cos_angle, cos_spot_angle);
507					float spot_rim = max(0.0001, (1.0 - scos) / (1.0 - cos_spot_angle));
508					attenuation *= 1.0 - pow(spot_rim, light_data.inv_spot_attenuation);
509				}
510			}
511		
512			attenuation *= max(0.0, dot(p_normal, r_light_dir));
513			if (attenuation <= 0.0001) {
514				return;
515			}
516		
517			float penumbra = 0.0;
518			if ((light_data.size > 0.0) && p_soft_shadowing) {
519				vec3 light_to_point = -r_light_dir;
520				vec3 aux = light_to_point.y < 0.777 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
521				vec3 light_to_point_tan = normalize(cross(light_to_point, aux));
522				vec3 light_to_point_bitan = normalize(cross(light_to_point, light_to_point_tan));
523		
524				const uint shadowing_rays_check_penumbra_denom = 2;
525				uint shadowing_ray_count = p_soft_shadowing ? params.ray_count : 1;
526		
527				uint hits = 0;
528				vec3 light_disk_to_point = light_to_point;
529				for (uint j = 0; j < shadowing_ray_count; j++) {
530					// Optimization:
531					// Once already traced an important proportion of rays, if all are hits or misses,
532					// assume we're not in the penumbra so we can infer the rest would have the same result
533					if (p_soft_shadowing) {
534						if (j == shadowing_ray_count / shadowing_rays_check_penumbra_denom) {
535							if (hits == j) {
536								// Assume totally lit
537								hits = shadowing_ray_count;
538								break;
539							} else if (hits == 0) {
540								// Assume totally dark
541								hits = 0;
542								break;
543							}
544						}
545					}
546		
547					float r = randomize(r_noise);
548					float a = randomize(r_noise) * 2.0 * PI;
549					vec2 disk_sample = (r * vec2(cos(a), sin(a))) * soft_shadowing_disk_size * light_data.shadow_blur;
550					light_disk_to_point = normalize(light_to_point + disk_sample.x * light_to_point_tan + disk_sample.y * light_to_point_bitan);
551		
552					if (trace_ray_any_hit(p_position - light_disk_to_point * bake_params.bias, p_position - light_disk_to_point * dist) == RAY_MISS) {
553						hits++;
554					}
555				}
556		
557				penumbra = float(hits) / float(shadowing_ray_count);
558			} else {
559				if (trace_ray_any_hit(p_position + r_light_dir * bake_params.bias, light_pos) == RAY_MISS) {
560					penumbra = 1.0;
561				}
562			}
563		
564			r_light = light_data.color * light_data.energy * attenuation * penumbra;
565		}
566		
567		#endif
568		
569		#if defined(MODE_BOUNCE_LIGHT) || defined(MODE_LIGHT_PROBES)
570		
571		vec3 trace_environment_color(vec3 ray_dir) {
572			vec3 sky_dir = normalize(mat3(bake_params.env_transform) * ray_dir);
573			vec2 st = vec2(atan(sky_dir.x, sky_dir.z), acos(sky_dir.y));
574			if (st.x < 0.0) {
575				st.x += PI * 2.0;
576			}
577		
578			return textureLod(sampler2D(environment, linear_sampler), st / vec2(PI * 2.0, PI), 0.0).rgb;
579		}
580		
581		vec3 trace_indirect_light(vec3 p_position, vec3 p_ray_dir, inout uint r_noise) {
582			// The lower limit considers the case where the lightmapper might have bounces disabled but light probes are requested.
583			vec3 position = p_position;
584			vec3 ray_dir = p_ray_dir;
585			uint max_depth = max(bake_params.bounces, 1);
586			vec3 throughput = vec3(1.0);
587			vec3 light = vec3(0.0);
588			for (uint depth = 0; depth < max_depth; depth++) {
589				uint tidx;
590				vec3 barycentric;
591				uint trace_result = trace_ray_closest_hit_triangle(position + ray_dir * bake_params.bias, position + ray_dir * length(bake_params.world_size), tidx, barycentric);
592				if (trace_result == RAY_FRONT) {
593					Vertex vert0 = vertices.data[triangles.data[tidx].indices.x];
594					Vertex vert1 = vertices.data[triangles.data[tidx].indices.y];
595					Vertex vert2 = vertices.data[triangles.data[tidx].indices.z];
596					vec3 uvw = vec3(barycentric.x * vert0.uv + barycentric.y * vert1.uv + barycentric.z * vert2.uv, float(triangles.data[tidx].slice));
597					position = barycentric.x * vert0.position + barycentric.y * vert1.position + barycentric.z * vert2.position;
598		
599					vec3 norm0 = vec3(vert0.normal_xy, vert0.normal_z);
600					vec3 norm1 = vec3(vert1.normal_xy, vert1.normal_z);
601					vec3 norm2 = vec3(vert2.normal_xy, vert2.normal_z);
602					vec3 normal = barycentric.x * norm0 + barycentric.y * norm1 + barycentric.z * norm2;
603		
604					vec3 direct_light = vec3(0.0f);
605		#ifdef USE_LIGHT_TEXTURE_FOR_BOUNCES
606					direct_light += textureLod(sampler2DArray(source_light, linear_sampler), uvw, 0.0).rgb;
607		#else
608					// Trace the lights directly. Significantly more expensive but more accurate in scenarios
609					// where the lightmap texture isn't reliable.
610					for (uint i = 0; i < bake_params.light_count; i++) {
611						vec3 light;
612						vec3 light_dir;
613						trace_direct_light(position, normal, i, false, light, light_dir, r_noise);
614						direct_light += light * lights.data[i].indirect_energy;
615					}
616		
617					direct_light *= bake_params.exposure_normalization;
618		#endif
619		
620					vec3 albedo = textureLod(sampler2DArray(albedo_tex, linear_sampler), uvw, 0).rgb;
621					vec3 emissive = textureLod(sampler2DArray(emission_tex, linear_sampler), uvw, 0).rgb;
622					emissive *= bake_params.exposure_normalization;
623		
624					light += throughput * emissive;
625					throughput *= albedo;
626					light += throughput * direct_light * bake_params.bounce_indirect_energy;
627		
628					// Use Russian Roulette to determine a probability to terminate the bounce earlier as an optimization.
629					// <https://computergraphics.stackexchange.com/questions/2316/is-russian-roulette-really-the-answer>
630					float p = max(max(throughput.x, throughput.y), throughput.z);
631					if (randomize(r_noise) > p) {
632						break;
633					}
634		
635					// Boost the throughput from the probability of the ray being terminated early.
636					throughput *= 1.0 / p;
637		
638					// Generate a new ray direction for the next bounce from this surface's normal.
639					ray_dir = generate_ray_dir_from_normal(normal, r_noise);
640				} else if (trace_result == RAY_MISS) {
641					// Look for the environment color and stop bouncing.
642					light += throughput * trace_environment_color(ray_dir);
643					break;
644				} else {
645					// Ignore any other trace results.
646					break;
647				}
648			}
649		
650			return light;
651		}
652		
653		#endif
654		
655		void main() {
656			// Check if invocation is out of bounds.
657		#ifdef MODE_LIGHT_PROBES
658			int probe_index = int(gl_GlobalInvocationID.x);
659			if (probe_index >= params.probe_count) {
660				return;
661			}
662		
663		#else
664			ivec2 atlas_pos = ivec2(gl_GlobalInvocationID.xy) + params.region_ofs;
665			if (any(greaterThanEqual(atlas_pos, bake_params.atlas_size))) {
666				return;
667			}
668		#endif
669		
670		#ifdef MODE_DIRECT_LIGHT
671		
672			vec3 normal = texelFetch(sampler2DArray(source_normal, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).xyz;
673			if (length(normal) < 0.5) {
674				return; //empty texel, no process
675			}
676			vec3 position = texelFetch(sampler2DArray(source_position, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).xyz;
677			vec3 light_for_texture = vec3(0.0);
678			vec3 light_for_bounces = vec3(0.0);
679		
680		#ifdef USE_SH_LIGHTMAPS
681			vec4 sh_accum[4] = vec4[](
682					vec4(0.0, 0.0, 0.0, 1.0),
683					vec4(0.0, 0.0, 0.0, 1.0),
684					vec4(0.0, 0.0, 0.0, 1.0),
685					vec4(0.0, 0.0, 0.0, 1.0));
686		#endif
687		
688			// Use atlas position and a prime number as the seed.
689			uint noise = random_seed(ivec3(atlas_pos, 43573547));
690			for (uint i = 0; i < bake_params.light_count; i++) {
691				vec3 light;
692				vec3 light_dir;
693				trace_direct_light(position, normal, i, true, light, light_dir, noise);
694		
695				if (lights.data[i].static_bake) {
696					light_for_texture += light;
697		
698		#ifdef USE_SH_LIGHTMAPS
699					float c[4] = float[](
700							0.282095, //l0
701							0.488603 * light_dir.y, //l1n1
702							0.488603 * light_dir.z, //l1n0
703							0.488603 * light_dir.x //l1p1
704					);
705		
706					for (uint j = 0; j < 4; j++) {
707						sh_accum[j].rgb += light * c[j] * 8.0;
708					}
709		#endif
710				}
711		
712				light_for_bounces += light * lights.data[i].indirect_energy;
713			}
714		
715			light_for_bounces *= bake_params.exposure_normalization;
716			imageStore(dest_light, ivec3(atlas_pos, params.atlas_slice), vec4(light_for_bounces, 1.0));
717		
718		#ifdef USE_SH_LIGHTMAPS
719			// Keep for adding at the end.
720			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + 0), sh_accum[0]);
721			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + 1), sh_accum[1]);
722			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + 2), sh_accum[2]);
723			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + 3), sh_accum[3]);
724		#else
725			light_for_texture *= bake_params.exposure_normalization;
726			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice), vec4(light_for_texture, 1.0));
727		#endif
728		
729		#endif
730		
731		#ifdef MODE_BOUNCE_LIGHT
732		
733		#ifdef USE_SH_LIGHTMAPS
734			vec4 sh_accum[4] = vec4[](
735					vec4(0.0, 0.0, 0.0, 1.0),
736					vec4(0.0, 0.0, 0.0, 1.0),
737					vec4(0.0, 0.0, 0.0, 1.0),
738					vec4(0.0, 0.0, 0.0, 1.0));
739		#else
740			vec3 light_accum = vec3(0.0);
741		#endif
742		
743			// Retrieve starting normal and position.
744			vec3 normal = texelFetch(sampler2DArray(source_normal, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).xyz;
745			if (length(normal) < 0.5) {
746				// The pixel is empty, skip processing it.
747				return;
748			}
749		
750			vec3 position = texelFetch(sampler2DArray(source_position, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).xyz;
751			uint noise = random_seed(ivec3(params.ray_from, atlas_pos));
752			for (uint i = params.ray_from; i < params.ray_to; i++) {
753				vec3 ray_dir = generate_ray_dir_from_normal(normal, noise);
754				vec3 light = trace_indirect_light(position, ray_dir, noise);
755		
756		#ifdef USE_SH_LIGHTMAPS
757				float c[4] = float[](
758						0.282095, //l0
759						0.488603 * ray_dir.y, //l1n1
760						0.488603 * ray_dir.z, //l1n0
761						0.488603 * ray_dir.x //l1p1
762				);
763		
764				for (uint j = 0; j < 4; j++) {
765					sh_accum[j].rgb += light * c[j] * 8.0;
766				}
767		#else
768				light_accum += light;
769		#endif
770			}
771		
772			// Add the averaged result to the accumulated light texture.
773		#ifdef USE_SH_LIGHTMAPS
774			for (int i = 0; i < 4; i++) {
775				vec4 accum = imageLoad(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + i));
776				accum.rgb += sh_accum[i].rgb / float(params.ray_count);
777				imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice * 4 + i), accum);
778			}
779		#else
780			vec4 accum = imageLoad(accum_light, ivec3(atlas_pos, params.atlas_slice));
781			accum.rgb += light_accum / float(params.ray_count);
782			imageStore(accum_light, ivec3(atlas_pos, params.atlas_slice), accum);
783		#endif
784		
785		#endif
786		
787		#ifdef MODE_UNOCCLUDE
788		
789			//texel_size = 0.5;
790			//compute tangents
791		
792			vec4 position_alpha = imageLoad(position, ivec3(atlas_pos, params.atlas_slice));
793			if (position_alpha.a < 0.5) {
794				return;
795			}
796		
797			vec3 vertex_pos = position_alpha.xyz;
798			vec4 normal_tsize = imageLoad(unocclude, ivec3(atlas_pos, params.atlas_slice));
799		
800			vec3 face_normal = normal_tsize.xyz;
801			float texel_size = normal_tsize.w;
802		
803			vec3 v0 = abs(face_normal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
804			vec3 tangent = normalize(cross(v0, face_normal));
805			vec3 bitangent = normalize(cross(tangent, face_normal));
806			vec3 base_pos = vertex_pos + face_normal * bake_params.bias; // Raise a bit.
807		
808			vec3 rays[4] = vec3[](tangent, bitangent, -tangent, -bitangent);
809			float min_d = 1e20;
810			for (int i = 0; i < 4; i++) {
811				vec3 ray_to = base_pos + rays[i] * texel_size;
812				float d;
813				vec3 norm;
814		
815				if (trace_ray_closest_hit_distance(base_pos, ray_to, d, norm) == RAY_BACK) {
816					if (d < min_d) {
817						// This bias needs to be greater than the regular bias, because otherwise later, rays will go the other side when pointing back.
818						vertex_pos = base_pos + rays[i] * d + norm * bake_params.bias * 10.0;
819						min_d = d;
820					}
821				}
822			}
823		
824			position_alpha.xyz = vertex_pos;
825		
826			imageStore(position, ivec3(atlas_pos, params.atlas_slice), position_alpha);
827		
828		#endif
829		
830		#ifdef MODE_LIGHT_PROBES
831		
832			vec3 position = probe_positions.data[probe_index].xyz;
833		
834			vec4 probe_sh_accum[9] = vec4[](
835					vec4(0.0),
836					vec4(0.0),
837					vec4(0.0),
838					vec4(0.0),
839					vec4(0.0),
840					vec4(0.0),
841					vec4(0.0),
842					vec4(0.0),
843					vec4(0.0));
844		
845			uint noise = random_seed(ivec3(params.ray_from, probe_index, 49502741 /* some prime */));
846			for (uint i = params.ray_from; i < params.ray_to; i++) {
847				vec3 ray_dir = generate_sphere_uniform_direction(noise);
848				vec3 light = trace_indirect_light(position, ray_dir, noise);
849		
850				float c[9] = float[](
851						0.282095, //l0
852						0.488603 * ray_dir.y, //l1n1
853						0.488603 * ray_dir.z, //l1n0
854						0.488603 * ray_dir.x, //l1p1
855						1.092548 * ray_dir.x * ray_dir.y, //l2n2
856						1.092548 * ray_dir.y * ray_dir.z, //l2n1
857						//0.315392 * (ray_dir.x * ray_dir.x + ray_dir.y * ray_dir.y + 2.0 * ray_dir.z * ray_dir.z), //l20
858						0.315392 * (3.0 * ray_dir.z * ray_dir.z - 1.0), //l20
859						1.092548 * ray_dir.x * ray_dir.z, //l2p1
860						0.546274 * (ray_dir.x * ray_dir.x - ray_dir.y * ray_dir.y) //l2p2
861				);
862		
863				for (uint j = 0; j < 9; j++) {
864					probe_sh_accum[j].rgb += light * c[j];
865				}
866			}
867		
868			if (params.ray_from > 0) {
869				for (uint j = 0; j < 9; j++) { //accum from existing
870					probe_sh_accum[j] += light_probes.data[probe_index * 9 + j];
871				}
872			}
873		
874			if (params.ray_to == params.ray_count) {
875				for (uint j = 0; j < 9; j++) { //accum from existing
876					probe_sh_accum[j] *= 4.0 / float(params.ray_count);
877				}
878			}
879		
880			for (uint j = 0; j < 9; j++) { //accum from existing
881				light_probes.data[probe_index * 9 + j] = probe_sh_accum[j];
882			}
883		
884		#endif
885		
886		#ifdef MODE_DILATE
887		
888			vec4 c = texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0);
889			//sides first, as they are closer
890			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-1, 0), params.atlas_slice), 0);
891			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(0, 1), params.atlas_slice), 0);
892			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(1, 0), params.atlas_slice), 0);
893			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(0, -1), params.atlas_slice), 0);
894			//endpoints second
895			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-1, -1), params.atlas_slice), 0);
896			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-1, 1), params.atlas_slice), 0);
897			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(1, -1), params.atlas_slice), 0);
898			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(1, 1), params.atlas_slice), 0);
899		
900			//far sides third
901			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-2, 0), params.atlas_slice), 0);
902			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(0, 2), params.atlas_slice), 0);
903			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(2, 0), params.atlas_slice), 0);
904			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(0, -2), params.atlas_slice), 0);
905		
906			//far-mid endpoints
907			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-2, -1), params.atlas_slice), 0);
908			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-2, 1), params.atlas_slice), 0);
909			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(2, -1), params.atlas_slice), 0);
910			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(2, 1), params.atlas_slice), 0);
911		
912			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-1, -2), params.atlas_slice), 0);
913			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-1, 2), params.atlas_slice), 0);
914			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(1, -2), params.atlas_slice), 0);
915			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(1, 2), params.atlas_slice), 0);
916			//far endpoints
917			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-2, -2), params.atlas_slice), 0);
918			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(-2, 2), params.atlas_slice), 0);
919			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(2, -2), params.atlas_slice), 0);
920			c = c.a > 0.5 ? c : texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos + ivec2(2, 2), params.atlas_slice), 0);
921		
922			imageStore(dest_light, ivec3(atlas_pos, params.atlas_slice), c);
923		
924		#endif
925		
926		#ifdef MODE_DENOISE
927			// Joint Non-local means (JNLM) denoiser.
928			//
929			// Based on YoctoImageDenoiser's JNLM implementation with corrections from "Nonlinearly Weighted First-order Regression for Denoising Monte Carlo Renderings".
930			//
931			// <https://github.com/ManuelPrandini/YoctoImageDenoiser/blob/06e19489dd64e47792acffde536393802ba48607/libs/yocto_extension/yocto_extension.cpp#L207>
932			// <https://benedikt-bitterli.me/nfor/nfor.pdf>
933			//
934			// MIT License
935			//
936			// Copyright (c) 2020 ManuelPrandini
937			//
938			// Permission is hereby granted, free of charge, to any person obtaining a copy
939			// of this software and associated documentation files (the "Software"), to deal
940			// in the Software without restriction, including without limitation the rights
941			// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
942			// copies of the Software, and to permit persons to whom the Software is
943			// furnished to do so, subject to the following conditions:
944			//
945			// The above copyright notice and this permission notice shall be included in all
946			// copies or substantial portions of the Software.
947			//
948			// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
949			// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
950			// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
951			// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
952			// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
953			// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
954			// SOFTWARE.
955			//
956			// Most of the constants below have been hand-picked to fit the common scenarios lightmaps
957			// are generated with, but they can be altered freely to experiment and achieve better results.
958		
959			// Half the size of the patch window around each pixel that is weighted to compute the denoised pixel.
960			// A value of 1 represents a 3x3 window, a value of 2 a 5x5 window, etc.
961			const int HALF_PATCH_WINDOW = 4;
962		
963			// Half the size of the search window around each pixel that is denoised and weighted to compute the denoised pixel.
964			const int HALF_SEARCH_WINDOW = 10;
965		
966			// For all of the following sigma values, smaller values will give less weight to pixels that have a bigger distance
967			// in the feature being evaluated. Therefore, smaller values are likely to cause more noise to appear, but will also
968			// cause less features to be erased in the process.
969		
970			// Controls how much the spatial distance of the pixels influences the denoising weight.
971			const float SIGMA_SPATIAL = denoise_params.spatial_bandwidth;
972		
973			// Controls how much the light color distance of the pixels influences the denoising weight.
974			const float SIGMA_LIGHT = denoise_params.light_bandwidth;
975		
976			// Controls how much the albedo color distance of the pixels influences the denoising weight.
977			const float SIGMA_ALBEDO = denoise_params.albedo_bandwidth;
978		
979			// Controls how much the normal vector distance of the pixels influences the denoising weight.
980			const float SIGMA_NORMAL = denoise_params.normal_bandwidth;
981		
982			// Strength of the filter. The original paper recommends values around 10 to 15 times the Sigma parameter.
983			const float FILTER_VALUE = denoise_params.filter_strength * SIGMA_LIGHT;
984		
985			// Formula constants.
986			const int PATCH_WINDOW_DIMENSION = (HALF_PATCH_WINDOW * 2 + 1);
987			const int PATCH_WINDOW_DIMENSION_SQUARE = (PATCH_WINDOW_DIMENSION * PATCH_WINDOW_DIMENSION);
988			const float TWO_SIGMA_SPATIAL_SQUARE = 2.0f * SIGMA_SPATIAL * SIGMA_SPATIAL;
989			const float TWO_SIGMA_LIGHT_SQUARE = 2.0f * SIGMA_LIGHT * SIGMA_LIGHT;
990			const float TWO_SIGMA_ALBEDO_SQUARE = 2.0f * SIGMA_ALBEDO * SIGMA_ALBEDO;
991			const float TWO_SIGMA_NORMAL_SQUARE = 2.0f * SIGMA_NORMAL * SIGMA_NORMAL;
992			const float FILTER_SQUARE_TWO_SIGMA_LIGHT_SQUARE = FILTER_VALUE * FILTER_VALUE * TWO_SIGMA_LIGHT_SQUARE;
993			const float EPSILON = 1e-6f;
994		
995		#ifdef USE_SH_LIGHTMAPS
996			const uint slice_count = 4;
997			const uint slice_base = params.atlas_slice * slice_count;
998		#else
999			const uint slice_count = 1;
1000			const uint slice_base = params.atlas_slice;
1001		#endif
1002		
1003			for (uint i = 0; i < slice_count; i++) {
1004				uint lightmap_slice = slice_base + i;
1005				vec3 denoised_rgb = vec3(0.0f);
1006				vec4 input_light = texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(atlas_pos, lightmap_slice), 0);
1007				vec3 input_albedo = texelFetch(sampler2DArray(albedo_tex, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).rgb;
1008				vec3 input_normal = texelFetch(sampler2DArray(source_normal, linear_sampler), ivec3(atlas_pos, params.atlas_slice), 0).xyz;
1009				if (length(input_normal) > EPSILON) {
1010					// Compute the denoised pixel if the normal is valid.
1011					float sum_weights = 0.0f;
1012					vec3 input_rgb = input_light.rgb;
1013					for (int search_y = -HALF_SEARCH_WINDOW; search_y <= HALF_SEARCH_WINDOW; search_y++) {
1014						for (int search_x = -HALF_SEARCH_WINDOW; search_x <= HALF_SEARCH_WINDOW; search_x++) {
1015							ivec2 search_pos = atlas_pos + ivec2(search_x, search_y);
1016							vec3 search_rgb = texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(search_pos, lightmap_slice), 0).rgb;
1017							vec3 search_albedo = texelFetch(sampler2DArray(albedo_tex, linear_sampler), ivec3(search_pos, params.atlas_slice), 0).rgb;
1018							vec3 search_normal = texelFetch(sampler2DArray(source_normal, linear_sampler), ivec3(search_pos, params.atlas_slice), 0).xyz;
1019							float patch_square_dist = 0.0f;
1020							for (int offset_y = -HALF_PATCH_WINDOW; offset_y <= HALF_PATCH_WINDOW; offset_y++) {
1021								for (int offset_x = -HALF_PATCH_WINDOW; offset_x <= HALF_PATCH_WINDOW; offset_x++) {
1022									ivec2 offset_input_pos = atlas_pos + ivec2(offset_x, offset_y);
1023									ivec2 offset_search_pos = search_pos + ivec2(offset_x, offset_y);
1024									vec3 offset_input_rgb = texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(offset_input_pos, lightmap_slice), 0).rgb;
1025									vec3 offset_search_rgb = texelFetch(sampler2DArray(source_light, linear_sampler), ivec3(offset_search_pos, lightmap_slice), 0).rgb;
1026									vec3 offset_delta_rgb = offset_input_rgb - offset_search_rgb;
1027									patch_square_dist += dot(offset_delta_rgb, offset_delta_rgb) - TWO_SIGMA_LIGHT_SQUARE;
1028								}
1029							}
1030		
1031							patch_square_dist = max(0.0f, patch_square_dist / (3.0f * PATCH_WINDOW_DIMENSION_SQUARE));
1032		
1033							float weight = 1.0f;
1034		
1035							// Ignore weight if search position is out of bounds.
1036							weight *= step(0, search_pos.x) * step(search_pos.x, bake_params.atlas_size.x - 1);
1037							weight *= step(0, search_pos.y) * step(search_pos.y, bake_params.atlas_size.y - 1);
1038		
1039							// Ignore weight if normal is zero length.
1040							weight *= step(EPSILON, length(search_normal));
1041		
1042							// Weight with pixel distance.
1043							vec2 pixel_delta = vec2(search_x, search_y);
1044							float pixel_square_dist = dot(pixel_delta, pixel_delta);
1045							weight *= exp(-pixel_square_dist / TWO_SIGMA_SPATIAL_SQUARE);
1046		
1047							// Weight with patch.
1048							weight *= exp(-patch_square_dist / FILTER_SQUARE_TWO_SIGMA_LIGHT_SQUARE);
1049		
1050							// Weight with albedo.
1051							vec3 albedo_delta = input_albedo - search_albedo;
1052							float albedo_square_dist = dot(albedo_delta, albedo_delta);
1053							weight *= exp(-albedo_square_dist / TWO_SIGMA_ALBEDO_SQUARE);
1054		
1055							// Weight with normal.
1056							vec3 normal_delta = input_normal - search_normal;
1057							float normal_square_dist = dot(normal_delta, normal_delta);
1058							weight *= exp(-normal_square_dist / TWO_SIGMA_NORMAL_SQUARE);
1059		
1060							denoised_rgb += weight * search_rgb;
1061							sum_weights += weight;
1062						}
1063					}
1064		
1065					denoised_rgb /= sum_weights;
1066				} else {
1067					// Ignore pixels where the normal is empty, just copy the light color.
1068					denoised_rgb = input_light.rgb;
1069				}
1070		
1071				imageStore(dest_light, ivec3(atlas_pos, lightmap_slice), vec4(denoised_rgb, input_light.a));
1072			}
1073		#endif
1074		}
1075		
1076		
          RDShaderFile                   denoise                 dilate                light_probes                primary             
   secondary             
   unocclude                RSRC