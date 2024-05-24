RSRC                    RDShaderFile            ��������                                                  resource_local_to_scene    resource_name    bytecode_vertex    bytecode_fragment    bytecode_tesselation_control     bytecode_tesselation_evaluation    bytecode_compute    compile_error_vertex    compile_error_fragment "   compile_error_tesselation_control %   compile_error_tesselation_evaluation    compile_error_compute    script 
   _versions    base_error           local://RDShaderSPIRV_yhm2g ;         local://RDShaderFile_1cfuo �!         RDShaderSPIRV            Failed parse:
ERROR: 0:78: 'output' : Reserved word. 
ERROR: 0:78: '' : compilation terminated 
ERROR: 2 compilation errors.  No code generated.




Stage 'compute' source code: 

1		
2		#version 450
3		
4		#
5		
6		layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
7		
8		#define NO_CHILDREN 0xFFFFFFFF
9		
10		struct CellChildren {
11			uint children[8];
12		};
13		
14		layout(set = 0, binding = 1, std430) buffer CellChildrenBuffer {
15			CellChildren data[];
16		}
17		cell_children;
18		
19		struct CellData {
20			uint position; // xyz 10 bits
21			uint albedo; //rgb albedo
22			uint emission; //rgb normalized with e as multiplier
23			uint normal; //RGB normal encoded
24		};
25		
26		layout(set = 0, binding = 2, std430) buffer CellDataBuffer {
27			CellData data[];
28		}
29		cell_data;
30		
31		#define LIGHT_TYPE_DIRECTIONAL 0
32		#define LIGHT_TYPE_OMNI 1
33		#define LIGHT_TYPE_SPOT 2
34		
35		#ifdef MODE_COMPUTE_LIGHT
36		
37		struct Light {
38			uint type;
39			float energy;
40			float radius;
41			float attenuation;
42		
43			vec3 color;
44			float cos_spot_angle;
45		
46			vec3 position;
47			float inv_spot_attenuation;
48		
49			vec3 direction;
50			bool has_shadow;
51		};
52		
53		layout(set = 0, binding = 3, std140) uniform Lights {
54			Light data[MAX_LIGHTS];
55		}
56		lights;
57		
58		#endif
59		
60		layout(push_constant, std430) uniform Params {
61			ivec3 limits;
62			uint stack_size;
63		
64			float emission_scale;
65			float propagation;
66			float dynamic_range;
67		
68			uint light_count;
69			uint cell_offset;
70			uint cell_count;
71			uint pad[2];
72		}
73		params;
74		
75		layout(set = 0, binding = 4, std140) uniform Outputs {
76			vec4 data[];
77		}
78		output;
79		
80		#ifdef MODE_COMPUTE_LIGHT
81		
82		uint raymarch(float distance, float distance_adv, vec3 from, vec3 direction) {
83			uint result = NO_CHILDREN;
84		
85			ivec3 size = ivec3(max(max(params.limits.x, params.limits.y), params.limits.z));
86		
87			while (distance > -distance_adv) { //use this to avoid precision errors
88				uint cell = 0;
89		
90				ivec3 pos = ivec3(from);
91		
92				if (all(greaterThanEqual(pos, ivec3(0))) && all(lessThan(pos, size))) {
93					ivec3 ofs = ivec3(0);
94					ivec3 half_size = size / 2;
95		
96					for (int i = 0; i < params.stack_size - 1; i++) {
97						bvec3 greater = greaterThanEqual(pos, ofs + half_size);
98		
99						ofs += mix(ivec3(0), half_size, greater);
100		
101						uint child = 0; //wonder if this can be done faster
102						if (greater.x) {
103							child |= 1;
104						}
105						if (greater.y) {
106							child |= 2;
107						}
108						if (greater.z) {
109							child |= 4;
110						}
111		
112						cell = cell_children.data[cell].children[child];
113						if (cell == NO_CHILDREN) {
114							break;
115						}
116		
117						half_size >>= ivec3(1);
118					}
119		
120					if (cell != NO_CHILDREN) {
121						return cell; //found cell!
122					}
123				}
124		
125				from += direction * distance_adv;
126				distance -= distance_adv;
127			}
128		
129			return NO_CHILDREN;
130		}
131		
132		bool compute_light_vector(uint light, uint cell, vec3 pos, out float attenuation, out vec3 light_pos) {
133			if (lights.data[light].type == LIGHT_TYPE_DIRECTIONAL) {
134				light_pos = pos - lights.data[light].direction * length(vec3(params.limits));
135				attenuation = 1.0;
136			} else {
137				light_pos = lights.data[light].position;
138				float distance = length(pos - light_pos);
139				if (distance >= lights.data[light].radius) {
140					return false;
141				}
142		
143				attenuation = pow(clamp(1.0 - distance / lights.data[light].radius, 0.0001, 1.0), lights.data[light].attenuation);
144		
145				if (lights.data[light].type == LIGHT_TYPE_SPOT) {
146					vec3 rel = normalize(pos - light_pos);
147					float cos_spot_angle = lights.data[light].cos_spot_angle;
148					float cos_angle = dot(rel, lights.data[light].direction);
149					if (cos_angle < cos_spot_angle) {
150						return false;
151					}
152		
153					float scos = max(cos_angle, cos_spot_angle);
154					float spot_rim = max(0.0001, (1.0 - scos) / (1.0 - cos_spot_angle));
155					attenuation *= 1.0 - pow(spot_rim, lights.data[light].inv_spot_attenuation);
156				}
157			}
158		
159			return true;
160		}
161		
162		float get_normal_advance(vec3 p_normal) {
163			vec3 normal = p_normal;
164			vec3 unorm = abs(normal);
165		
166			if ((unorm.x >= unorm.y) && (unorm.x >= unorm.z)) {
167				// x code
168				unorm = normal.x > 0.0 ? vec3(1.0, 0.0, 0.0) : vec3(-1.0, 0.0, 0.0);
169			} else if ((unorm.y > unorm.x) && (unorm.y >= unorm.z)) {
170				// y code
171				unorm = normal.y > 0.0 ? vec3(0.0, 1.0, 0.0) : vec3(0.0, -1.0, 0.0);
172			} else if ((unorm.z > unorm.x) && (unorm.z > unorm.y)) {
173				// z code
174				unorm = normal.z > 0.0 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 0.0, -1.0);
175			} else {
176				// oh-no we messed up code
177				// has to be
178				unorm = vec3(1.0, 0.0, 0.0);
179			}
180		
181			return 1.0 / dot(normal, unorm);
182		}
183		
184		#endif
185		
186		void main() {
187			uint cell_index = gl_GlobalInvocationID.x;
188			if (cell_index >= params.cell_count) {
189				return;
190			}
191			cell_index += params.cell_offset;
192		
193			uvec3 posu = uvec3(cell_data.data[cell_index].position & 0x7FF, (cell_data.data[cell_index].position >> 11) & 0x3FF, cell_data.data[cell_index].position >> 21);
194			vec4 albedo = unpackUnorm4x8(cell_data.data[cell_index].albedo);
195		
196		#ifdef MODE_COMPUTE_LIGHT
197		
198			vec3 pos = vec3(posu) + vec3(0.5);
199		
200			vec3 emission = vec3(ivec3(cell_data.data[cell_index].emission & 0x3FF, (cell_data.data[cell_index].emission >> 10) & 0x7FF, cell_data.data[cell_index].emission >> 21)) * params.emission_scale;
201			vec4 normal = unpackSnorm4x8(cell_data.data[cell_index].normal);
202		
203			vec3 accum = vec3(0.0);
204		
205			for (uint i = 0; i < params.light_count; i++) {
206				float attenuation;
207				vec3 light_pos;
208		
209				if (!compute_light_vector(i, cell_index, pos, attenuation, light_pos)) {
210					continue;
211				}
212		
213				vec3 light_dir = pos - light_pos;
214				float distance = length(light_dir);
215				light_dir = normalize(light_dir);
216		
217				if (length(normal.xyz) > 0.2 && dot(normal.xyz, light_dir) >= 0) {
218					continue; //not facing the light
219				}
220		
221				if (lights.data[i].has_shadow) {
222					float distance_adv = get_normal_advance(light_dir);
223		
224					distance += distance_adv - mod(distance, distance_adv); //make it reach the center of the box always
225		
226					vec3 from = pos - light_dir * distance; //approximate
227					from -= sign(light_dir) * 0.45; //go near the edge towards the light direction to avoid self occlusion
228		
229					uint result = raymarch(distance, distance_adv, from, light_dir);
230		
231					if (result != cell_index) {
232						continue; //was occluded
233					}
234				}
235		
236				vec3 light = lights.data[i].color * albedo.rgb * attenuation * lights.data[i].energy;
237		
238				if (length(normal.xyz) > 0.2) {
239					accum += max(0.0, dot(normal.xyz, -light_dir)) * light + emission;
240				} else {
241					//all directions
242					accum += light + emission;
243				}
244			}
245		
246			output.data[cell_index] = vec4(accum, 0.0);
247		
248		#endif //MODE_COMPUTE_LIGHT
249		
250		#ifdef MODE_UPDATE_MIPMAPS
251		
252			{
253				vec3 light_accum = vec3(0.0);
254				float count = 0.0;
255				for (uint i = 0; i < 8; i++) {
256					uint child_index = cell_children.data[cell_index].children[i];
257					if (child_index == NO_CHILDREN) {
258						continue;
259					}
260					light_accum += output.data[child_index].rgb;
261		
262					count += 1.0;
263				}
264		
265				float divisor = mix(8.0, count, params.propagation);
266				output.data[cell_index] = vec4(light_accum / divisor, 0.0);
267			}
268		#endif
269		
270		#ifdef MODE_WRITE_TEXTURE
271			{
272			}
273		#endif
274		}
275		
276		
          RDShaderFile                                    RSRC