RSRC                    RDShaderFile            ��������                                                  resource_local_to_scene    resource_name    bytecode_vertex    bytecode_fragment    bytecode_tesselation_control     bytecode_tesselation_evaluation    bytecode_compute    compile_error_vertex    compile_error_fragment "   compile_error_tesselation_control %   compile_error_tesselation_evaluation    compile_error_compute    script 
   _versions    base_error           local://RDShaderSPIRV_yenyr ;         local://RDShaderFile_ag4tc a         RDShaderSPIRV          �^  Failed parse:
ERROR: 0:13: 'SAMPLERS_BINDING_FIRST_INDEX' : undeclared identifier 
ERROR: 0:13: '' : compilation terminated 
ERROR: 2 compilation errors.  No code generated.




Stage 'compute' source code: 

1		
2		#version 450
3		
4		#
5		
6		layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
7		
8		#define SDF_MAX_LENGTH 16384.0
9		
10		/* SET 0: GLOBAL DATA */
11		
12		
13		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 0) uniform sampler SAMPLER_NEAREST_CLAMP;
14		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 1) uniform sampler SAMPLER_LINEAR_CLAMP;
15		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 2) uniform sampler SAMPLER_NEAREST_WITH_MIPMAPS_CLAMP;
16		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 3) uniform sampler SAMPLER_LINEAR_WITH_MIPMAPS_CLAMP;
17		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 4) uniform sampler SAMPLER_NEAREST_WITH_MIPMAPS_ANISOTROPIC_CLAMP;
18		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 5) uniform sampler SAMPLER_LINEAR_WITH_MIPMAPS_ANISOTROPIC_CLAMP;
19		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 6) uniform sampler SAMPLER_NEAREST_REPEAT;
20		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 7) uniform sampler SAMPLER_LINEAR_REPEAT;
21		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 8) uniform sampler SAMPLER_NEAREST_WITH_MIPMAPS_REPEAT;
22		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 9) uniform sampler SAMPLER_LINEAR_WITH_MIPMAPS_REPEAT;
23		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 10) uniform sampler SAMPLER_NEAREST_WITH_MIPMAPS_ANISOTROPIC_REPEAT;
24		layout(set = 0, binding = SAMPLERS_BINDING_FIRST_INDEX + 11) uniform sampler SAMPLER_LINEAR_WITH_MIPMAPS_ANISOTROPIC_REPEAT;
25		
26		layout(set = 0, binding = 2, std430) restrict readonly buffer GlobalShaderUniformData {
27			vec4 data[];
28		}
29		global_shader_uniforms;
30		
31		/* Set 1: FRAME AND PARTICLE DATA */
32		
33		// a frame history is kept for trail deterministic behavior
34		
35		#define MAX_ATTRACTORS 32
36		
37		#define ATTRACTOR_TYPE_SPHERE 0
38		#define ATTRACTOR_TYPE_BOX 1
39		#define ATTRACTOR_TYPE_VECTOR_FIELD 2
40		
41		struct Attractor {
42			mat4 transform;
43			vec3 extents; //exents or radius
44			uint type;
45			uint texture_index; //texture index for vector field
46			float strength;
47			float attenuation;
48			float directionality;
49		};
50		
51		#define MAX_COLLIDERS 32
52		
53		#define COLLIDER_TYPE_SPHERE 0
54		#define COLLIDER_TYPE_BOX 1
55		#define COLLIDER_TYPE_SDF 2
56		#define COLLIDER_TYPE_HEIGHT_FIELD 3
57		#define COLLIDER_TYPE_2D_SDF 4
58		
59		struct Collider {
60			mat4 transform;
61			vec3 extents; //exents or radius
62			uint type;
63		
64			uint texture_index; //texture index for vector field
65			float scale;
66			uint pad[2];
67		};
68		
69		struct FrameParams {
70			bool emitting;
71			float system_phase;
72			float prev_system_phase;
73			uint cycle;
74		
75			float explosiveness;
76			float randomness;
77			float time;
78			float delta;
79		
80			uint frame;
81			float amount_ratio;
82			uint pad1;
83			uint pad2;
84		
85			uint random_seed;
86			uint attractor_count;
87			uint collider_count;
88			float particle_size;
89		
90			mat4 emission_transform;
91			vec3 emitter_velocity;
92			float interp_to_end;
93		
94			Attractor attractors[MAX_ATTRACTORS];
95			Collider colliders[MAX_COLLIDERS];
96		};
97		
98		layout(set = 1, binding = 0, std430) restrict buffer FrameHistory {
99			FrameParams data[];
100		}
101		frame_history;
102		
103		#define PARTICLE_FLAG_ACTIVE uint(1)
104		#define PARTICLE_FLAG_STARTED uint(2)
105		#define PARTICLE_FLAG_TRAILED uint(4)
106		#define PARTICLE_FRAME_MASK uint(0xFFFF)
107		#define PARTICLE_FRAME_SHIFT uint(16)
108		
109		struct ParticleData {
110			mat4 xform;
111			vec3 velocity;
112			uint flags;
113			vec4 color;
114			vec4 custom;
115		#ifdef USERDATA1_USED
116			vec4 userdata1;
117		#endif
118		#ifdef USERDATA2_USED
119			vec4 userdata2;
120		#endif
121		#ifdef USERDATA3_USED
122			vec4 userdata3;
123		#endif
124		#ifdef USERDATA4_USED
125			vec4 userdata4;
126		#endif
127		#ifdef USERDATA5_USED
128			vec4 userdata5;
129		#endif
130		#ifdef USERDATA6_USED
131			vec4 userdata6;
132		#endif
133		};
134		
135		layout(set = 1, binding = 1, std430) restrict buffer Particles {
136			ParticleData data[];
137		}
138		particles;
139		
140		#define EMISSION_FLAG_HAS_POSITION 1
141		#define EMISSION_FLAG_HAS_ROTATION_SCALE 2
142		#define EMISSION_FLAG_HAS_VELOCITY 4
143		#define EMISSION_FLAG_HAS_COLOR 8
144		#define EMISSION_FLAG_HAS_CUSTOM 16
145		
146		struct ParticleEmission {
147			mat4 xform;
148			vec3 velocity;
149			uint flags;
150			vec4 color;
151			vec4 custom;
152		};
153		
154		layout(set = 1, binding = 2, std430) restrict buffer SourceEmission {
155			int particle_count;
156			uint pad0;
157			uint pad1;
158			uint pad2;
159			ParticleEmission data[];
160		}
161		src_particles;
162		
163		layout(set = 1, binding = 3, std430) restrict buffer DestEmission {
164			int particle_count;
165			int particle_max;
166			uint pad1;
167			uint pad2;
168			ParticleEmission data[];
169		}
170		dst_particles;
171		
172		/* SET 2: COLLIDER/ATTRACTOR TEXTURES */
173		
174		#define MAX_3D_TEXTURES 7
175		
176		layout(set = 2, binding = 0) uniform texture3D sdf_vec_textures[MAX_3D_TEXTURES];
177		layout(set = 2, binding = 1) uniform texture2D height_field_texture;
178		
179		/* SET 3: MATERIAL */
180		
181		#ifdef MATERIAL_UNIFORMS_USED
182		layout(set = 3, binding = 0, std140) uniform MaterialUniforms{
183		
184		#MATERIAL_UNIFORMS
185		
186		} material;
187		#endif
188		
189		layout(push_constant, std430) uniform Params {
190			float lifetime;
191			bool clear;
192			uint total_particles;
193			uint trail_size;
194			bool use_fractional_delta;
195			bool sub_emitter_mode;
196			bool can_emit;
197			bool trail_pass;
198		}
199		params;
200		
201		uint hash(uint x) {
202			x = ((x >> uint(16)) ^ x) * uint(0x45d9f3b);
203			x = ((x >> uint(16)) ^ x) * uint(0x45d9f3b);
204			x = (x >> uint(16)) ^ x;
205			return x;
206		}
207		
208		bool emit_subparticle(mat4 p_xform, vec3 p_velocity, vec4 p_color, vec4 p_custom, uint p_flags) {
209			if (!params.can_emit) {
210				return false;
211			}
212		
213			bool valid = false;
214		
215			int dst_index = atomicAdd(dst_particles.particle_count, 1);
216		
217			if (dst_index >= dst_particles.particle_max) {
218				atomicAdd(dst_particles.particle_count, -1);
219				return false;
220			}
221		
222			dst_particles.data[dst_index].xform = p_xform;
223			dst_particles.data[dst_index].velocity = p_velocity;
224			dst_particles.data[dst_index].color = p_color;
225			dst_particles.data[dst_index].custom = p_custom;
226			dst_particles.data[dst_index].flags = p_flags;
227		
228			return true;
229		}
230		
231		vec3 safe_normalize(vec3 direction) {
232			const float EPSILON = 0.001;
233			if (length(direction) < EPSILON) {
234				return vec3(0.0);
235			}
236			return normalize(direction);
237		}
238		
239		#GLOBALS
240		
241		void main() {
242			uint particle = gl_GlobalInvocationID.x;
243		
244			if (params.trail_size > 1) {
245				if (params.trail_pass) {
246					if (particle >= params.total_particles * (params.trail_size - 1)) {
247						return;
248					}
249					particle += (particle / (params.trail_size - 1)) + 1;
250				} else {
251					if (particle >= params.total_particles) {
252						return;
253					}
254					particle *= params.trail_size;
255				}
256			}
257		
258			if (particle >= params.total_particles * params.trail_size) {
259				return; //discard
260			}
261		
262			uint index = particle / params.trail_size;
263			uint frame = (particle % params.trail_size);
264		
265		#define FRAME frame_history.data[frame]
266		#define PARTICLE particles.data[particle]
267		
268			bool apply_forces = true;
269			bool apply_velocity = true;
270			float local_delta = FRAME.delta;
271		
272			float mass = 1.0;
273		
274			bool restart = false;
275		
276			bool restart_position = false;
277			bool restart_rotation_scale = false;
278			bool restart_velocity = false;
279			bool restart_color = false;
280			bool restart_custom = false;
281		
282			if (params.clear) {
283				PARTICLE.color = vec4(1.0);
284				PARTICLE.custom = vec4(0.0);
285				PARTICLE.velocity = vec3(0.0);
286				PARTICLE.flags = 0;
287				PARTICLE.xform = mat4(
288						vec4(1.0, 0.0, 0.0, 0.0),
289						vec4(0.0, 1.0, 0.0, 0.0),
290						vec4(0.0, 0.0, 1.0, 0.0),
291						vec4(0.0, 0.0, 0.0, 1.0));
292			}
293		
294			//clear started flag if set
295		
296			if (params.trail_pass) {
297				//trail started
298				uint src_idx = index * params.trail_size;
299				if (bool(particles.data[src_idx].flags & PARTICLE_FLAG_STARTED)) {
300					//save start conditions for trails
301					PARTICLE.color = particles.data[src_idx].color;
302					PARTICLE.custom = particles.data[src_idx].custom;
303					PARTICLE.velocity = particles.data[src_idx].velocity;
304					PARTICLE.flags = PARTICLE_FLAG_TRAILED | ((frame_history.data[0].frame & PARTICLE_FRAME_MASK) << PARTICLE_FRAME_SHIFT); //mark it as trailed, save in which frame it will start
305					PARTICLE.xform = particles.data[src_idx].xform;
306				}
307				if (!bool(particles.data[src_idx].flags & PARTICLE_FLAG_ACTIVE)) {
308					// Disable the entire trail if the parent is no longer active.
309					PARTICLE.flags = 0;
310					return;
311				}
312				if (bool(PARTICLE.flags & PARTICLE_FLAG_TRAILED) && ((PARTICLE.flags >> PARTICLE_FRAME_SHIFT) == (FRAME.frame & PARTICLE_FRAME_MASK))) { //check this is trailed and see if it should start now
313					// we just assume that this is the first frame of the particle, the rest is deterministic
314					PARTICLE.flags = PARTICLE_FLAG_ACTIVE | (particles.data[src_idx].flags & (PARTICLE_FRAME_MASK << PARTICLE_FRAME_SHIFT));
315					return; //- this appears like it should be correct, but it seems not to be.. wonder why.
316				}
317		
318			} else {
319				PARTICLE.flags &= ~PARTICLE_FLAG_STARTED;
320			}
321		
322			bool collided = false;
323			vec3 collision_normal = vec3(0.0);
324			float collision_depth = 0.0;
325		
326			vec3 attractor_force = vec3(0.0);
327		
328		#if !defined(DISABLE_VELOCITY)
329		
330			if (bool(PARTICLE.flags & PARTICLE_FLAG_ACTIVE)) {
331				PARTICLE.xform[3].xyz += PARTICLE.velocity * local_delta;
332			}
333		#endif
334		
335			if (!params.trail_pass && params.sub_emitter_mode) {
336				if (!bool(PARTICLE.flags & PARTICLE_FLAG_ACTIVE)) {
337					int src_index = atomicAdd(src_particles.particle_count, -1) - 1;
338		
339					if (src_index >= 0) {
340						PARTICLE.flags = (PARTICLE_FLAG_ACTIVE | PARTICLE_FLAG_STARTED | (FRAME.cycle << PARTICLE_FRAME_SHIFT));
341						restart = true;
342		
343						if (bool(src_particles.data[src_index].flags & EMISSION_FLAG_HAS_POSITION)) {
344							PARTICLE.xform[3] = src_particles.data[src_index].xform[3];
345						} else {
346							PARTICLE.xform[3] = vec4(0, 0, 0, 1);
347							restart_position = true;
348						}
349						if (bool(src_particles.data[src_index].flags & EMISSION_FLAG_HAS_ROTATION_SCALE)) {
350							PARTICLE.xform[0] = src_particles.data[src_index].xform[0];
351							PARTICLE.xform[1] = src_particles.data[src_index].xform[1];
352							PARTICLE.xform[2] = src_particles.data[src_index].xform[2];
353						} else {
354							PARTICLE.xform[0] = vec4(1, 0, 0, 0);
355							PARTICLE.xform[1] = vec4(0, 1, 0, 0);
356							PARTICLE.xform[2] = vec4(0, 0, 1, 0);
357							restart_rotation_scale = true;
358						}
359						if (bool(src_particles.data[src_index].flags & EMISSION_FLAG_HAS_VELOCITY)) {
360							PARTICLE.velocity = src_particles.data[src_index].velocity;
361						} else {
362							PARTICLE.velocity = vec3(0);
363							restart_velocity = true;
364						}
365						if (bool(src_particles.data[src_index].flags & EMISSION_FLAG_HAS_COLOR)) {
366							PARTICLE.color = src_particles.data[src_index].color;
367						} else {
368							PARTICLE.color = vec4(1);
369							restart_color = true;
370						}
371		
372						if (bool(src_particles.data[src_index].flags & EMISSION_FLAG_HAS_CUSTOM)) {
373							PARTICLE.custom = src_particles.data[src_index].custom;
374						} else {
375							PARTICLE.custom = vec4(0);
376							restart_custom = true;
377						}
378					}
379				}
380		
381			} else if (FRAME.emitting) {
382				float restart_phase = float(index) / float(params.total_particles);
383		
384				if (FRAME.randomness > 0.0) {
385					uint seed = FRAME.cycle;
386					if (restart_phase >= FRAME.system_phase) {
387						seed -= uint(1);
388					}
389					seed *= uint(params.total_particles);
390					seed += uint(index);
391					float random = float(hash(seed) % uint(65536)) / 65536.0;
392					restart_phase += FRAME.randomness * random * 1.0 / float(params.total_particles);
393				}
394		
395				restart_phase *= (1.0 - FRAME.explosiveness);
396		
397				if (FRAME.system_phase > FRAME.prev_system_phase) {
398					// restart_phase >= prev_system_phase is used so particles emit in the first frame they are processed
399		
400					if (restart_phase >= FRAME.prev_system_phase && restart_phase < FRAME.system_phase) {
401						restart = true;
402						if (params.use_fractional_delta) {
403							local_delta = (FRAME.system_phase - restart_phase) * params.lifetime;
404						}
405					}
406		
407				} else if (FRAME.delta > 0.0) {
408					if (restart_phase >= FRAME.prev_system_phase) {
409						restart = true;
410						if (params.use_fractional_delta) {
411							local_delta = (1.0 - restart_phase + FRAME.system_phase) * params.lifetime;
412						}
413		
414					} else if (restart_phase < FRAME.system_phase) {
415						restart = true;
416						if (params.use_fractional_delta) {
417							local_delta = (FRAME.system_phase - restart_phase) * params.lifetime;
418						}
419					}
420				}
421		
422				if (params.trail_pass) {
423					restart = false;
424				}
425		
426				if (restart) {
427					PARTICLE.flags = FRAME.emitting ? (PARTICLE_FLAG_ACTIVE | PARTICLE_FLAG_STARTED | (FRAME.cycle << PARTICLE_FRAME_SHIFT)) : 0;
428					restart_position = true;
429					restart_rotation_scale = true;
430					restart_velocity = true;
431					restart_color = true;
432					restart_custom = true;
433				}
434			}
435		
436			bool particle_active = bool(PARTICLE.flags & PARTICLE_FLAG_ACTIVE);
437		
438			uint particle_number = (PARTICLE.flags >> PARTICLE_FRAME_SHIFT) * uint(params.total_particles) + index;
439		
440			if (restart && particle_active) {
441		#CODE : START
442			}
443		
444			if (particle_active) {
445				for (uint i = 0; i < FRAME.attractor_count; i++) {
446					vec3 dir;
447					float amount;
448					vec3 rel_vec = PARTICLE.xform[3].xyz - FRAME.attractors[i].transform[3].xyz;
449					vec3 local_pos = rel_vec * mat3(FRAME.attractors[i].transform);
450		
451					switch (FRAME.attractors[i].type) {
452						case ATTRACTOR_TYPE_SPHERE: {
453							dir = safe_normalize(rel_vec);
454							float d = length(local_pos) / FRAME.attractors[i].extents.x;
455							if (d > 1.0) {
456								continue;
457							}
458							amount = max(0.0, 1.0 - d);
459						} break;
460						case ATTRACTOR_TYPE_BOX: {
461							dir = safe_normalize(rel_vec);
462		
463							vec3 abs_pos = abs(local_pos / FRAME.attractors[i].extents);
464							float d = max(abs_pos.x, max(abs_pos.y, abs_pos.z));
465							if (d > 1.0) {
466								continue;
467							}
468							amount = max(0.0, 1.0 - d);
469		
470						} break;
471						case ATTRACTOR_TYPE_VECTOR_FIELD: {
472							vec3 uvw_pos = (local_pos / FRAME.attractors[i].extents + 1.0) * 0.5;
473							if (any(lessThan(uvw_pos, vec3(0.0))) || any(greaterThan(uvw_pos, vec3(1.0)))) {
474								continue;
475							}
476							vec3 s = texture(sampler3D(sdf_vec_textures[FRAME.attractors[i].texture_index], SAMPLER_LINEAR_CLAMP), uvw_pos).xyz * -2.0 + 1.0;
477							dir = mat3(FRAME.attractors[i].transform) * safe_normalize(s); //revert direction
478							amount = length(s);
479		
480						} break;
481					}
482					amount = pow(amount, FRAME.attractors[i].attenuation);
483					dir = safe_normalize(mix(dir, FRAME.attractors[i].transform[2].xyz, FRAME.attractors[i].directionality));
484					attractor_force -= amount * dir * FRAME.attractors[i].strength;
485				}
486		
487				float particle_size = FRAME.particle_size;
488		
489		#ifdef USE_COLLISION_SCALE
490		
491				particle_size *= dot(vec3(length(PARTICLE.xform[0].xyz), length(PARTICLE.xform[1].xyz), length(PARTICLE.xform[2].xyz)), vec3(0.33333333333));
492		
493		#endif
494		
495				if (FRAME.collider_count == 1 && FRAME.colliders[0].type == COLLIDER_TYPE_2D_SDF) {
496					//2D collision
497		
498					vec2 pos = PARTICLE.xform[3].xy;
499					vec4 to_sdf_x = FRAME.colliders[0].transform[0];
500					vec4 to_sdf_y = FRAME.colliders[0].transform[1];
501					vec2 sdf_pos = vec2(dot(vec4(pos, 0, 1), to_sdf_x), dot(vec4(pos, 0, 1), to_sdf_y));
502		
503					vec4 sdf_to_screen = vec4(FRAME.colliders[0].extents, FRAME.colliders[0].scale);
504		
505					vec2 uv_pos = sdf_pos * sdf_to_screen.xy + sdf_to_screen.zw;
506		
507					if (all(greaterThan(uv_pos, vec2(0.0))) && all(lessThan(uv_pos, vec2(1.0)))) {
508						vec2 pos2 = pos + vec2(0, particle_size);
509						vec2 sdf_pos2 = vec2(dot(vec4(pos2, 0, 1), to_sdf_x), dot(vec4(pos2, 0, 1), to_sdf_y));
510						float sdf_particle_size = distance(sdf_pos, sdf_pos2);
511		
512						float d = texture(sampler2D(height_field_texture, SAMPLER_LINEAR_CLAMP), uv_pos).r * SDF_MAX_LENGTH;
513		
514						d -= sdf_particle_size;
515		
516						if (d < 0.0) {
517							const float EPSILON = 0.001;
518							vec2 n = normalize(vec2(
519									texture(sampler2D(height_field_texture, SAMPLER_LINEAR_CLAMP), uv_pos + vec2(EPSILON, 0.0)).r - texture(sampler2D(height_field_texture, SAMPLER_LINEAR_CLAMP), uv_pos - vec2(EPSILON, 0.0)).r,
520									texture(sampler2D(height_field_texture, SAMPLER_LINEAR_CLAMP), uv_pos + vec2(0.0, EPSILON)).r - texture(sampler2D(height_field_texture, SAMPLER_LINEAR_CLAMP), uv_pos - vec2(0.0, EPSILON)).r));
521		
522							collided = true;
523							sdf_pos2 = sdf_pos + n * d;
524							pos2 = vec2(dot(vec4(sdf_pos2, 0, 1), FRAME.colliders[0].transform[2]), dot(vec4(sdf_pos2, 0, 1), FRAME.colliders[0].transform[3]));
525		
526							n = pos - pos2;
527		
528							collision_normal = normalize(vec3(n, 0.0));
529							collision_depth = length(n);
530						}
531					}
532		
533				} else {
534					for (uint i = 0; i < FRAME.collider_count; i++) {
535						vec3 normal;
536						float depth;
537						bool col = false;
538		
539						vec3 rel_vec = PARTICLE.xform[3].xyz - FRAME.colliders[i].transform[3].xyz;
540						vec3 local_pos = rel_vec * mat3(FRAME.colliders[i].transform);
541		
542						switch (FRAME.colliders[i].type) {
543							case COLLIDER_TYPE_SPHERE: {
544								float d = length(rel_vec) - (particle_size + FRAME.colliders[i].extents.x);
545		
546								if (d < 0.0) {
547									col = true;
548									depth = -d;
549									normal = normalize(rel_vec);
550								}
551		
552							} break;
553							case COLLIDER_TYPE_BOX: {
554								vec3 abs_pos = abs(local_pos);
555								vec3 sgn_pos = sign(local_pos);
556		
557								if (any(greaterThan(abs_pos, FRAME.colliders[i].extents))) {
558									//point outside box
559		
560									vec3 closest = min(abs_pos, FRAME.colliders[i].extents);
561									vec3 rel = abs_pos - closest;
562									depth = length(rel) - particle_size;
563									if (depth < 0.0) {
564										col = true;
565										normal = mat3(FRAME.colliders[i].transform) * (normalize(rel) * sgn_pos);
566										depth = -depth;
567									}
568								} else {
569									//point inside box
570									vec3 axis_len = FRAME.colliders[i].extents - abs_pos;
571									// there has to be a faster way to do this?
572									if (all(lessThan(axis_len.xx, axis_len.yz))) {
573										normal = vec3(1, 0, 0);
574									} else if (all(lessThan(axis_len.yy, axis_len.xz))) {
575										normal = vec3(0, 1, 0);
576									} else {
577										normal = vec3(0, 0, 1);
578									}
579		
580									col = true;
581									depth = dot(normal * axis_len, vec3(1)) + particle_size;
582									normal = mat3(FRAME.colliders[i].transform) * (normal * sgn_pos);
583								}
584		
585							} break;
586							case COLLIDER_TYPE_SDF: {
587								vec3 apos = abs(local_pos);
588								float extra_dist = 0.0;
589								if (any(greaterThan(apos, FRAME.colliders[i].extents))) { //outside
590									vec3 mpos = min(apos, FRAME.colliders[i].extents);
591									extra_dist = distance(mpos, apos);
592								}
593		
594								if (extra_dist > particle_size) {
595									continue;
596								}
597		
598								vec3 uvw_pos = (local_pos / FRAME.colliders[i].extents) * 0.5 + 0.5;
599								float s = texture(sampler3D(sdf_vec_textures[FRAME.colliders[i].texture_index], SAMPLER_LINEAR_CLAMP), uvw_pos).r;
600								s *= FRAME.colliders[i].scale;
601								s += extra_dist;
602								if (s < particle_size) {
603									col = true;
604									depth = particle_size - s;
605									const float EPSILON = 0.001;
606									normal = mat3(FRAME.colliders[i].transform) *
607											normalize(
608													vec3(
609															texture(sampler3D(sdf_vec_textures[FRAME.colliders[i].texture_index], SAMPLER_LINEAR_CLAMP), uvw_pos + vec3(EPSILON, 0.0, 0.0)).r - texture(sampler3D(sdf_vec_textures[FRAME.colliders[i].texture_index], SAMPLER_LINEAR_CLAMP), uvw_pos - vec3(EPSILON, 0.0, 0.0)).r,
610															texture(sampler3D(sdf_vec_textures[FRAME.colliders[i].texture_index], SAMPLER_LINEAR_CLAMP), uvw_pos + vec3(0.0, EPSILON, 0.0)).r - texture(sampler3D(sdf_vec_textures[FRAME.colliders[i].texture_index], SAMPLER_LINEAR_CLAMP), uvw_pos - vec3(0.0, EPSILON, 0.0)).r,
611															texture(sampler3D(sdf_vec_textures[FRAME.colliders[i].texture_index], SAMPLER_LINEAR_CLAMP), uvw_pos + vec3(0.0, 0.0, EPSILON)).r - texture(sampler3D(sdf_vec_textures[FRAME.colliders[i].texture_index], SAMPLER_LINEAR_CLAMP), uvw_pos - vec3(0.0, 0.0, EPSILON)).r));
612								}
613		
614							} break;
615							case COLLIDER_TYPE_HEIGHT_FIELD: {
616								vec3 local_pos_bottom = local_pos;
617								local_pos_bottom.y -= particle_size;
618		
619								if (any(greaterThan(abs(local_pos_bottom), FRAME.colliders[i].extents))) {
620									continue;
621								}
622								const float DELTA = 1.0 / 8192.0;
623		
624								vec3 uvw_pos = vec3(local_pos_bottom / FRAME.colliders[i].extents) * 0.5 + 0.5;
625		
626								float y = 1.0 - texture(sampler2D(height_field_texture, SAMPLER_LINEAR_CLAMP), uvw_pos.xz).r;
627		
628								if (y > uvw_pos.y) {
629									//inside heightfield
630		
631									vec3 pos1 = (vec3(uvw_pos.x, y, uvw_pos.z) * 2.0 - 1.0) * FRAME.colliders[i].extents;
632									vec3 pos2 = (vec3(uvw_pos.x + DELTA, 1.0 - texture(sampler2D(height_field_texture, SAMPLER_LINEAR_CLAMP), uvw_pos.xz + vec2(DELTA, 0)).r, uvw_pos.z) * 2.0 - 1.0) * FRAME.colliders[i].extents;
633									vec3 pos3 = (vec3(uvw_pos.x, 1.0 - texture(sampler2D(height_field_texture, SAMPLER_LINEAR_CLAMP), uvw_pos.xz + vec2(0, DELTA)).r, uvw_pos.z + DELTA) * 2.0 - 1.0) * FRAME.colliders[i].extents;
634		
635									normal = normalize(cross(pos1 - pos2, pos1 - pos3));
636									float local_y = (vec3(local_pos / FRAME.colliders[i].extents) * 0.5 + 0.5).y;
637		
638									col = true;
639									depth = dot(normal, pos1) - dot(normal, local_pos_bottom);
640								}
641		
642							} break;
643						}
644		
645						if (col) {
646							if (!collided) {
647								collided = true;
648								collision_normal = normal;
649								collision_depth = depth;
650							} else {
651								vec3 c = collision_normal * collision_depth;
652								c += normal * max(0.0, depth - dot(normal, c));
653								collision_normal = normalize(c);
654								collision_depth = length(c);
655							}
656						}
657					}
658				}
659			}
660		
661			if (particle_active) {
662		#CODE : PROCESS
663			}
664		
665			PARTICLE.flags &= ~PARTICLE_FLAG_ACTIVE;
666			if (particle_active) {
667				PARTICLE.flags |= PARTICLE_FLAG_ACTIVE;
668			}
669		}
670		
671		
          RDShaderFile                                    RSRC