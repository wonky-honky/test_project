RSRC                    RDShaderFile            ��������                                                  resource_local_to_scene    resource_name    bytecode_vertex    bytecode_fragment    bytecode_tesselation_control     bytecode_tesselation_evaluation    bytecode_compute    compile_error_vertex    compile_error_fragment "   compile_error_tesselation_control %   compile_error_tesselation_evaluation    compile_error_compute    script 
   _versions    base_error           local://RDShaderSPIRV_wrhqv ;         local://RDShaderFile_y4x60 (�         RDShaderSPIRV          �/  Failed parse:
ERROR: 0:134: 'MAX_LIGHTS' : undeclared identifier 
ERROR: 0:134: '' : array size must be a constant integer expression
ERROR: 0:134: '' : compilation terminated 
ERROR: 3 compilation errors.  No code generated.




Stage 'vertex' source code: 

1		
2		#version 450
3		
4		#
5		
6		#ifdef USE_ATTRIBUTES
7		layout(location = 0) in vec2 vertex_attrib;
8		layout(location = 3) in vec4 color_attrib;
9		layout(location = 4) in vec2 uv_attrib;
10		
11		layout(location = 10) in uvec4 bone_attrib;
12		layout(location = 11) in vec4 weight_attrib;
13		
14		#endif
15		
16		
17		
18		#define MAX_LIGHTS_PER_ITEM 16
19		
20		#define M_PI 3.14159265359
21		
22		#define SDF_MAX_LENGTH 16384.0
23		
24		//1 means enabled, 2+ means trails in use
25		#define FLAGS_INSTANCING_MASK 0x7F
26		#define FLAGS_INSTANCING_HAS_COLORS (1 << 7)
27		#define FLAGS_INSTANCING_HAS_CUSTOM_DATA (1 << 8)
28		
29		#define FLAGS_CLIP_RECT_UV (1 << 9)
30		#define FLAGS_TRANSPOSE_RECT (1 << 10)
31		#define FLAGS_CONVERT_ATTRIBUTES_TO_LINEAR (1 << 11)
32		#define FLAGS_NINEPACH_DRAW_CENTER (1 << 12)
33		#define FLAGS_USING_PARTICLES (1 << 13)
34		
35		#define FLAGS_NINEPATCH_H_MODE_SHIFT 16
36		#define FLAGS_NINEPATCH_V_MODE_SHIFT 18
37		
38		#define FLAGS_LIGHT_COUNT_SHIFT 20
39		
40		#define FLAGS_DEFAULT_NORMAL_MAP_USED (1 << 26)
41		#define FLAGS_DEFAULT_SPECULAR_MAP_USED (1 << 27)
42		
43		#define FLAGS_USE_MSDF (1 << 28)
44		#define FLAGS_USE_LCD (1 << 29)
45		
46		#define FLAGS_FLIP_H (1 << 30)
47		#define FLAGS_FLIP_V (1 << 31)
48		
49		// Push Constant
50		
51		layout(push_constant, std430) uniform DrawData {
52			vec2 world_x;
53			vec2 world_y;
54			vec2 world_ofs;
55			uint flags;
56			uint specular_shininess;
57		#ifdef USE_PRIMITIVE
58			vec2 points[3];
59			vec2 uvs[3];
60			uint colors[6];
61		#else
62			vec4 modulation;
63			vec4 ninepatch_margins;
64			vec4 dst_rect; //for built-in rect and UV
65			vec4 src_rect;
66			vec2 pad;
67		
68		#endif
69			vec2 color_texture_pixel_size;
70			uint lights[4];
71		}
72		draw_data;
73		
74		// In vulkan, sets should always be ordered using the following logic:
75		// Lower Sets: Sets that change format and layout less often
76		// Higher sets: Sets that change format and layout very often
77		// This is because changing a set for another with a different layout or format,
78		// invalidates all the upper ones (as likely internal base offset changes)
79		
80		/* SET0: Globals */
81		
82		// The values passed per draw primitives are cached within it
83		
84		layout(set = 0, binding = 1, std140) uniform CanvasData {
85			mat4 canvas_transform;
86			mat4 screen_transform;
87			mat4 canvas_normal_transform;
88			vec4 canvas_modulation;
89			vec2 screen_pixel_size;
90			float time;
91			bool use_pixel_snap;
92		
93			vec4 sdf_to_tex;
94			vec2 screen_to_sdf;
95			vec2 sdf_to_screen;
96		
97			uint directional_light_count;
98			float tex_to_sdf;
99			uint pad1;
100			uint pad2;
101		}
102		canvas_data;
103		
104		#define LIGHT_FLAGS_BLEND_MASK (3 << 16)
105		#define LIGHT_FLAGS_BLEND_MODE_ADD (0 << 16)
106		#define LIGHT_FLAGS_BLEND_MODE_SUB (1 << 16)
107		#define LIGHT_FLAGS_BLEND_MODE_MIX (2 << 16)
108		#define LIGHT_FLAGS_BLEND_MODE_MASK (3 << 16)
109		#define LIGHT_FLAGS_HAS_SHADOW (1 << 20)
110		#define LIGHT_FLAGS_FILTER_SHIFT 22
111		#define LIGHT_FLAGS_FILTER_MASK (3 << 22)
112		#define LIGHT_FLAGS_SHADOW_NEAREST (0 << 22)
113		#define LIGHT_FLAGS_SHADOW_PCF5 (1 << 22)
114		#define LIGHT_FLAGS_SHADOW_PCF13 (2 << 22)
115		
116		struct Light {
117			mat2x4 texture_matrix; //light to texture coordinate matrix (transposed)
118			mat2x4 shadow_matrix; //light to shadow coordinate matrix (transposed)
119			vec4 color;
120		
121			uint shadow_color; // packed
122			uint flags; //index to light texture
123			float shadow_pixel_size;
124			float height;
125		
126			vec2 position;
127			float shadow_zfar_inv;
128			float shadow_y_ofs;
129		
130			vec4 atlas_rect;
131		};
132		
133		layout(set = 0, binding = 2, std140) uniform LightData {
134			Light data[MAX_LIGHTS];
135		}
136		light_array;
137		
138		layout(set = 0, binding = 3) uniform texture2D atlas_texture;
139		layout(set = 0, binding = 4) uniform texture2D shadow_atlas_texture;
140		
141		layout(set = 0, binding = 5) uniform sampler shadow_sampler;
142		
143		layout(set = 0, binding = 6) uniform texture2D color_buffer;
144		layout(set = 0, binding = 7) uniform texture2D sdf_texture;
145		
146		#include "samplers_inc.glsl"
147		
148		layout(set = 0, binding = 9, std430) restrict readonly buffer GlobalShaderUniformData {
149			vec4 data[];
150		}
151		global_shader_uniforms;
152		
153		/* SET1: Is reserved for the material */
154		
155		//
156		
157		/* SET2: Instancing and Skeleton */
158		
159		layout(set = 2, binding = 0, std430) restrict readonly buffer Transforms {
160			vec4 data[];
161		}
162		transforms;
163		
164		/* SET3: Texture */
165		
166		layout(set = 3, binding = 0) uniform texture2D color_texture;
167		layout(set = 3, binding = 1) uniform texture2D normal_texture;
168		layout(set = 3, binding = 2) uniform texture2D specular_texture;
169		layout(set = 3, binding = 3) uniform sampler texture_sampler;
170		
171		
172		layout(location = 0) out vec2 uv_interp;
173		layout(location = 1) out vec4 color_interp;
174		layout(location = 2) out vec2 vertex_interp;
175		
176		#ifdef USE_NINEPATCH
177		
178		layout(location = 3) out vec2 pixel_size_interp;
179		
180		#endif
181		
182		#ifdef MATERIAL_UNIFORMS_USED
183		layout(set = 1, binding = 0, std140) uniform MaterialUniforms{
184		
185		#MATERIAL_UNIFORMS
186		
187		} material;
188		#endif
189		
190		#GLOBALS
191		
192		#ifdef USE_ATTRIBUTES
193		vec3 srgb_to_linear(vec3 color) {
194			return mix(pow((color.rgb + vec3(0.055)) * (1.0 / (1.0 + 0.055)), vec3(2.4)), color.rgb * (1.0 / 12.92), lessThan(color.rgb, vec3(0.04045)));
195		}
196		#endif
197		
198		void main() {
199			vec4 instance_custom = vec4(0.0);
200		#ifdef USE_PRIMITIVE
201		
202			//weird bug,
203			//this works
204			vec2 vertex;
205			vec2 uv;
206			vec4 color;
207		
208			if (gl_VertexIndex == 0) {
209				vertex = draw_data.points[0];
210				uv = draw_data.uvs[0];
211				color = vec4(unpackHalf2x16(draw_data.colors[0]), unpackHalf2x16(draw_data.colors[1]));
212			} else if (gl_VertexIndex == 1) {
213				vertex = draw_data.points[1];
214				uv = draw_data.uvs[1];
215				color = vec4(unpackHalf2x16(draw_data.colors[2]), unpackHalf2x16(draw_data.colors[3]));
216			} else {
217				vertex = draw_data.points[2];
218				uv = draw_data.uvs[2];
219				color = vec4(unpackHalf2x16(draw_data.colors[4]), unpackHalf2x16(draw_data.colors[5]));
220			}
221			uvec4 bones = uvec4(0, 0, 0, 0);
222			vec4 bone_weights = vec4(0.0);
223		
224		#elif defined(USE_ATTRIBUTES)
225		
226			vec2 vertex = vertex_attrib;
227			vec4 color = color_attrib;
228			if (bool(draw_data.flags & FLAGS_CONVERT_ATTRIBUTES_TO_LINEAR)) {
229				color.rgb = srgb_to_linear(color.rgb);
230			}
231			color *= draw_data.modulation;
232			vec2 uv = uv_attrib;
233		
234			uvec4 bones = bone_attrib;
235			vec4 bone_weights = weight_attrib;
236		#else
237		
238			vec2 vertex_base_arr[4] = vec2[](vec2(0.0, 0.0), vec2(0.0, 1.0), vec2(1.0, 1.0), vec2(1.0, 0.0));
239			vec2 vertex_base = vertex_base_arr[gl_VertexIndex];
240		
241			vec2 uv = draw_data.src_rect.xy + abs(draw_data.src_rect.zw) * ((draw_data.flags & FLAGS_TRANSPOSE_RECT) != 0 ? vertex_base.yx : vertex_base.xy);
242			vec4 color = draw_data.modulation;
243			vec2 vertex = draw_data.dst_rect.xy + abs(draw_data.dst_rect.zw) * mix(vertex_base, vec2(1.0, 1.0) - vertex_base, lessThan(draw_data.src_rect.zw, vec2(0.0, 0.0)));
244			uvec4 bones = uvec4(0, 0, 0, 0);
245		
246		#endif
247		
248			mat4 model_matrix = mat4(vec4(draw_data.world_x, 0.0, 0.0), vec4(draw_data.world_y, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(draw_data.world_ofs, 0.0, 1.0));
249		
250		#define FLAGS_INSTANCING_MASK 0x7F
251		#define FLAGS_INSTANCING_HAS_COLORS (1 << 7)
252		#define FLAGS_INSTANCING_HAS_CUSTOM_DATA (1 << 8)
253		
254			uint instancing = draw_data.flags & FLAGS_INSTANCING_MASK;
255		
256		#ifdef USE_ATTRIBUTES
257			if (instancing > 1) {
258				// trails
259		
260				uint stride = 2 + 1 + 1; //particles always uses this format
261		
262				uint trail_size = instancing;
263		
264				uint offset = trail_size * stride * gl_InstanceIndex;
265		
266				vec4 pcolor;
267				vec2 new_vertex;
268				{
269					uint boffset = offset + bone_attrib.x * stride;
270					new_vertex = (vec4(vertex, 0.0, 1.0) * mat4(transforms.data[boffset + 0], transforms.data[boffset + 1], vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0))).xy * weight_attrib.x;
271					pcolor = transforms.data[boffset + 2] * weight_attrib.x;
272				}
273				if (weight_attrib.y > 0.001) {
274					uint boffset = offset + bone_attrib.y * stride;
275					new_vertex += (vec4(vertex, 0.0, 1.0) * mat4(transforms.data[boffset + 0], transforms.data[boffset + 1], vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0))).xy * weight_attrib.y;
276					pcolor += transforms.data[boffset + 2] * weight_attrib.y;
277				}
278				if (weight_attrib.z > 0.001) {
279					uint boffset = offset + bone_attrib.z * stride;
280					new_vertex += (vec4(vertex, 0.0, 1.0) * mat4(transforms.data[boffset + 0], transforms.data[boffset + 1], vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0))).xy * weight_attrib.z;
281					pcolor += transforms.data[boffset + 2] * weight_attrib.z;
282				}
283				if (weight_attrib.w > 0.001) {
284					uint boffset = offset + bone_attrib.w * stride;
285					new_vertex += (vec4(vertex, 0.0, 1.0) * mat4(transforms.data[boffset + 0], transforms.data[boffset + 1], vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0))).xy * weight_attrib.w;
286					pcolor += transforms.data[boffset + 2] * weight_attrib.w;
287				}
288		
289				instance_custom = transforms.data[offset + 3];
290		
291				vertex = new_vertex;
292				color *= pcolor;
293			} else
294		#endif // USE_ATTRIBUTES
295			{
296				if (instancing == 1) {
297					uint stride = 2;
298					{
299						if (bool(draw_data.flags & FLAGS_INSTANCING_HAS_COLORS)) {
300							stride += 1;
301						}
302						if (bool(draw_data.flags & FLAGS_INSTANCING_HAS_CUSTOM_DATA)) {
303							stride += 1;
304						}
305					}
306		
307					uint offset = stride * gl_InstanceIndex;
308		
309					mat4 matrix = mat4(transforms.data[offset + 0], transforms.data[offset + 1], vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
310					offset += 2;
311		
312					if (bool(draw_data.flags & FLAGS_INSTANCING_HAS_COLORS)) {
313						color *= transforms.data[offset];
314						offset += 1;
315					}
316		
317					if (bool(draw_data.flags & FLAGS_INSTANCING_HAS_CUSTOM_DATA)) {
318						instance_custom = transforms.data[offset];
319					}
320		
321					matrix = transpose(matrix);
322					model_matrix = model_matrix * matrix;
323				}
324			}
325		
326		#if !defined(USE_ATTRIBUTES) && !defined(USE_PRIMITIVE)
327			if (bool(draw_data.flags & FLAGS_USING_PARTICLES)) {
328				//scale by texture size
329				vertex /= draw_data.color_texture_pixel_size;
330			}
331		#endif
332		
333		#ifdef USE_POINT_SIZE
334			float point_size = 1.0;
335		#endif
336		
337		#ifdef USE_WORLD_VERTEX_COORDS
338			vertex = (model_matrix * vec4(vertex, 0.0, 1.0)).xy;
339		#endif
340			{
341		#CODE : VERTEX
342			}
343		
344		#ifdef USE_NINEPATCH
345			pixel_size_interp = abs(draw_data.dst_rect.zw) * vertex_base;
346		#endif
347		
348		#if !defined(SKIP_TRANSFORM_USED) && !defined(USE_WORLD_VERTEX_COORDS)
349			vertex = (model_matrix * vec4(vertex, 0.0, 1.0)).xy;
350		#endif
351		
352			color_interp = color;
353		
354			if (canvas_data.use_pixel_snap) {
355				vertex = floor(vertex + 0.5);
356				// precision issue on some hardware creates artifacts within texture
357				// offset uv by a small amount to avoid
358				uv += 1e-5;
359			}
360		
361			vertex = (canvas_data.canvas_transform * vec4(vertex, 0.0, 1.0)).xy;
362		
363			vertex_interp = vertex;
364			uv_interp = uv;
365		
366			gl_Position = canvas_data.screen_transform * vec4(vertex, 0.0, 1.0);
367		
368		#ifdef USE_POINT_SIZE
369			gl_PointSize = point_size;
370		#endif
371		}
372		
373		
       c  Failed parse:
ERROR: 0:124: 'MAX_LIGHTS' : undeclared identifier 
ERROR: 0:124: '' : array size must be a constant integer expression
ERROR: 0:124: '' : compilation terminated 
ERROR: 3 compilation errors.  No code generated.




Stage 'fragment' source code: 

1		
2		#version 450
3		
4		#
5		
6		
7		
8		#define MAX_LIGHTS_PER_ITEM 16
9		
10		#define M_PI 3.14159265359
11		
12		#define SDF_MAX_LENGTH 16384.0
13		
14		//1 means enabled, 2+ means trails in use
15		#define FLAGS_INSTANCING_MASK 0x7F
16		#define FLAGS_INSTANCING_HAS_COLORS (1 << 7)
17		#define FLAGS_INSTANCING_HAS_CUSTOM_DATA (1 << 8)
18		
19		#define FLAGS_CLIP_RECT_UV (1 << 9)
20		#define FLAGS_TRANSPOSE_RECT (1 << 10)
21		#define FLAGS_CONVERT_ATTRIBUTES_TO_LINEAR (1 << 11)
22		#define FLAGS_NINEPACH_DRAW_CENTER (1 << 12)
23		#define FLAGS_USING_PARTICLES (1 << 13)
24		
25		#define FLAGS_NINEPATCH_H_MODE_SHIFT 16
26		#define FLAGS_NINEPATCH_V_MODE_SHIFT 18
27		
28		#define FLAGS_LIGHT_COUNT_SHIFT 20
29		
30		#define FLAGS_DEFAULT_NORMAL_MAP_USED (1 << 26)
31		#define FLAGS_DEFAULT_SPECULAR_MAP_USED (1 << 27)
32		
33		#define FLAGS_USE_MSDF (1 << 28)
34		#define FLAGS_USE_LCD (1 << 29)
35		
36		#define FLAGS_FLIP_H (1 << 30)
37		#define FLAGS_FLIP_V (1 << 31)
38		
39		// Push Constant
40		
41		layout(push_constant, std430) uniform DrawData {
42			vec2 world_x;
43			vec2 world_y;
44			vec2 world_ofs;
45			uint flags;
46			uint specular_shininess;
47		#ifdef USE_PRIMITIVE
48			vec2 points[3];
49			vec2 uvs[3];
50			uint colors[6];
51		#else
52			vec4 modulation;
53			vec4 ninepatch_margins;
54			vec4 dst_rect; //for built-in rect and UV
55			vec4 src_rect;
56			vec2 pad;
57		
58		#endif
59			vec2 color_texture_pixel_size;
60			uint lights[4];
61		}
62		draw_data;
63		
64		// In vulkan, sets should always be ordered using the following logic:
65		// Lower Sets: Sets that change format and layout less often
66		// Higher sets: Sets that change format and layout very often
67		// This is because changing a set for another with a different layout or format,
68		// invalidates all the upper ones (as likely internal base offset changes)
69		
70		/* SET0: Globals */
71		
72		// The values passed per draw primitives are cached within it
73		
74		layout(set = 0, binding = 1, std140) uniform CanvasData {
75			mat4 canvas_transform;
76			mat4 screen_transform;
77			mat4 canvas_normal_transform;
78			vec4 canvas_modulation;
79			vec2 screen_pixel_size;
80			float time;
81			bool use_pixel_snap;
82		
83			vec4 sdf_to_tex;
84			vec2 screen_to_sdf;
85			vec2 sdf_to_screen;
86		
87			uint directional_light_count;
88			float tex_to_sdf;
89			uint pad1;
90			uint pad2;
91		}
92		canvas_data;
93		
94		#define LIGHT_FLAGS_BLEND_MASK (3 << 16)
95		#define LIGHT_FLAGS_BLEND_MODE_ADD (0 << 16)
96		#define LIGHT_FLAGS_BLEND_MODE_SUB (1 << 16)
97		#define LIGHT_FLAGS_BLEND_MODE_MIX (2 << 16)
98		#define LIGHT_FLAGS_BLEND_MODE_MASK (3 << 16)
99		#define LIGHT_FLAGS_HAS_SHADOW (1 << 20)
100		#define LIGHT_FLAGS_FILTER_SHIFT 22
101		#define LIGHT_FLAGS_FILTER_MASK (3 << 22)
102		#define LIGHT_FLAGS_SHADOW_NEAREST (0 << 22)
103		#define LIGHT_FLAGS_SHADOW_PCF5 (1 << 22)
104		#define LIGHT_FLAGS_SHADOW_PCF13 (2 << 22)
105		
106		struct Light {
107			mat2x4 texture_matrix; //light to texture coordinate matrix (transposed)
108			mat2x4 shadow_matrix; //light to shadow coordinate matrix (transposed)
109			vec4 color;
110		
111			uint shadow_color; // packed
112			uint flags; //index to light texture
113			float shadow_pixel_size;
114			float height;
115		
116			vec2 position;
117			float shadow_zfar_inv;
118			float shadow_y_ofs;
119		
120			vec4 atlas_rect;
121		};
122		
123		layout(set = 0, binding = 2, std140) uniform LightData {
124			Light data[MAX_LIGHTS];
125		}
126		light_array;
127		
128		layout(set = 0, binding = 3) uniform texture2D atlas_texture;
129		layout(set = 0, binding = 4) uniform texture2D shadow_atlas_texture;
130		
131		layout(set = 0, binding = 5) uniform sampler shadow_sampler;
132		
133		layout(set = 0, binding = 6) uniform texture2D color_buffer;
134		layout(set = 0, binding = 7) uniform texture2D sdf_texture;
135		
136		#include "samplers_inc.glsl"
137		
138		layout(set = 0, binding = 9, std430) restrict readonly buffer GlobalShaderUniformData {
139			vec4 data[];
140		}
141		global_shader_uniforms;
142		
143		/* SET1: Is reserved for the material */
144		
145		//
146		
147		/* SET2: Instancing and Skeleton */
148		
149		layout(set = 2, binding = 0, std430) restrict readonly buffer Transforms {
150			vec4 data[];
151		}
152		transforms;
153		
154		/* SET3: Texture */
155		
156		layout(set = 3, binding = 0) uniform texture2D color_texture;
157		layout(set = 3, binding = 1) uniform texture2D normal_texture;
158		layout(set = 3, binding = 2) uniform texture2D specular_texture;
159		layout(set = 3, binding = 3) uniform sampler texture_sampler;
160		
161		
162		layout(location = 0) in vec2 uv_interp;
163		layout(location = 1) in vec4 color_interp;
164		layout(location = 2) in vec2 vertex_interp;
165		
166		#ifdef USE_NINEPATCH
167		
168		layout(location = 3) in vec2 pixel_size_interp;
169		
170		#endif
171		
172		layout(location = 0) out vec4 frag_color;
173		
174		#ifdef MATERIAL_UNIFORMS_USED
175		layout(set = 1, binding = 0, std140) uniform MaterialUniforms{
176		
177		#MATERIAL_UNIFORMS
178		
179		} material;
180		#endif
181		
182		vec2 screen_uv_to_sdf(vec2 p_uv) {
183			return canvas_data.screen_to_sdf * p_uv;
184		}
185		
186		float texture_sdf(vec2 p_sdf) {
187			vec2 uv = p_sdf * canvas_data.sdf_to_tex.xy + canvas_data.sdf_to_tex.zw;
188			float d = texture(sampler2D(sdf_texture, SAMPLER_LINEAR_CLAMP), uv).r;
189			d *= SDF_MAX_LENGTH;
190			return d * canvas_data.tex_to_sdf;
191		}
192		
193		vec2 texture_sdf_normal(vec2 p_sdf) {
194			vec2 uv = p_sdf * canvas_data.sdf_to_tex.xy + canvas_data.sdf_to_tex.zw;
195		
196			const float EPSILON = 0.001;
197			return normalize(vec2(
198					texture(sampler2D(sdf_texture, SAMPLER_LINEAR_CLAMP), uv + vec2(EPSILON, 0.0)).r - texture(sampler2D(sdf_texture, SAMPLER_LINEAR_CLAMP), uv - vec2(EPSILON, 0.0)).r,
199					texture(sampler2D(sdf_texture, SAMPLER_LINEAR_CLAMP), uv + vec2(0.0, EPSILON)).r - texture(sampler2D(sdf_texture, SAMPLER_LINEAR_CLAMP), uv - vec2(0.0, EPSILON)).r));
200		}
201		
202		vec2 sdf_to_screen_uv(vec2 p_sdf) {
203			return p_sdf * canvas_data.sdf_to_screen;
204		}
205		
206		#GLOBALS
207		
208		#ifdef LIGHT_CODE_USED
209		
210		vec4 light_compute(
211				vec3 light_vertex,
212				vec3 light_position,
213				vec3 normal,
214				vec4 light_color,
215				float light_energy,
216				vec4 specular_shininess,
217				inout vec4 shadow_modulate,
218				vec2 screen_uv,
219				vec2 uv,
220				vec4 color, bool is_directional) {
221			vec4 light = vec4(0.0);
222			vec3 light_direction = vec3(0.0);
223		
224			if (is_directional) {
225				light_direction = normalize(mix(vec3(light_position.xy, 0.0), vec3(0, 0, 1), light_position.z));
226				light_position = vec3(0.0);
227			} else {
228				light_direction = normalize(light_position - light_vertex);
229			}
230		
231		#CODE : LIGHT
232		
233			return light;
234		}
235		
236		#endif
237		
238		#ifdef USE_NINEPATCH
239		
240		float map_ninepatch_axis(float pixel, float draw_size, float tex_pixel_size, float margin_begin, float margin_end, int np_repeat, inout int draw_center) {
241			float tex_size = 1.0 / tex_pixel_size;
242		
243			if (pixel < margin_begin) {
244				return pixel * tex_pixel_size;
245			} else if (pixel >= draw_size - margin_end) {
246				return (tex_size - (draw_size - pixel)) * tex_pixel_size;
247			} else {
248				if (!bool(draw_data.flags & FLAGS_NINEPACH_DRAW_CENTER)) {
249					draw_center--;
250				}
251		
252				// np_repeat is passed as uniform using NinePatchRect::AxisStretchMode enum.
253				if (np_repeat == 0) { // Stretch.
254					// Convert to ratio.
255					float ratio = (pixel - margin_begin) / (draw_size - margin_begin - margin_end);
256					// Scale to source texture.
257					return (margin_begin + ratio * (tex_size - margin_begin - margin_end)) * tex_pixel_size;
258				} else if (np_repeat == 1) { // Tile.
259					// Convert to offset.
260					float ofs = mod((pixel - margin_begin), tex_size - margin_begin - margin_end);
261					// Scale to source texture.
262					return (margin_begin + ofs) * tex_pixel_size;
263				} else if (np_repeat == 2) { // Tile Fit.
264					// Calculate scale.
265					float src_area = draw_size - margin_begin - margin_end;
266					float dst_area = tex_size - margin_begin - margin_end;
267					float scale = max(1.0, floor(src_area / max(dst_area, 0.0000001) + 0.5));
268					// Convert to ratio.
269					float ratio = (pixel - margin_begin) / src_area;
270					ratio = mod(ratio * scale, 1.0);
271					// Scale to source texture.
272					return (margin_begin + ratio * dst_area) * tex_pixel_size;
273				} else { // Shouldn't happen, but silences compiler warning.
274					return 0.0;
275				}
276			}
277		}
278		
279		#endif
280		
281		#ifdef USE_LIGHTING
282		
283		vec3 light_normal_compute(vec3 light_vec, vec3 normal, vec3 base_color, vec3 light_color, vec4 specular_shininess, bool specular_shininess_used) {
284			float cNdotL = max(0.0, dot(normal, light_vec));
285		
286			if (specular_shininess_used) {
287				//blinn
288				vec3 view = vec3(0.0, 0.0, 1.0); // not great but good enough
289				vec3 half_vec = normalize(view + light_vec);
290		
291				float cNdotV = max(dot(normal, view), 0.0);
292				float cNdotH = max(dot(normal, half_vec), 0.0);
293				float cVdotH = max(dot(view, half_vec), 0.0);
294				float cLdotH = max(dot(light_vec, half_vec), 0.0);
295				float shininess = exp2(15.0 * specular_shininess.a + 1.0) * 0.25;
296				float blinn = pow(cNdotH, shininess);
297				blinn *= (shininess + 8.0) * (1.0 / (8.0 * M_PI));
298				float s = (blinn) / max(4.0 * cNdotV * cNdotL, 0.75);
299		
300				return specular_shininess.rgb * light_color * s + light_color * base_color * cNdotL;
301			} else {
302				return light_color * base_color * cNdotL;
303			}
304		}
305		
306		//float distance = length(shadow_pos);
307		vec4 light_shadow_compute(uint light_base, vec4 light_color, vec4 shadow_uv
308		#ifdef LIGHT_CODE_USED
309				,
310				vec3 shadow_modulate
311		#endif
312		) {
313			float shadow;
314			uint shadow_mode = light_array.data[light_base].flags & LIGHT_FLAGS_FILTER_MASK;
315		
316			if (shadow_mode == LIGHT_FLAGS_SHADOW_NEAREST) {
317				shadow = textureProjLod(sampler2DShadow(shadow_atlas_texture, shadow_sampler), shadow_uv, 0.0).x;
318			} else if (shadow_mode == LIGHT_FLAGS_SHADOW_PCF5) {
319				vec4 shadow_pixel_size = vec4(light_array.data[light_base].shadow_pixel_size, 0.0, 0.0, 0.0);
320				shadow = 0.0;
321				shadow += textureProjLod(sampler2DShadow(shadow_atlas_texture, shadow_sampler), shadow_uv - shadow_pixel_size * 2.0, 0.0).x;
322				shadow += textureProjLod(sampler2DShadow(shadow_atlas_texture, shadow_sampler), shadow_uv - shadow_pixel_size, 0.0).x;
323				shadow += textureProjLod(sampler2DShadow(shadow_atlas_texture, shadow_sampler), shadow_uv, 0.0).x;
324				shadow += textureProjLod(sampler2DShadow(shadow_atlas_texture, shadow_sampler), shadow_uv + shadow_pixel_size, 0.0).x;
325				shadow += textureProjLod(sampler2DShadow(shadow_atlas_texture, shadow_sampler), shadow_uv + shadow_pixel_size * 2.0, 0.0).x;
326				shadow /= 5.0;
327			} else { //PCF13
328				vec4 shadow_pixel_size = vec4(light_array.data[light_base].shadow_pixel_size, 0.0, 0.0, 0.0);
329				shadow = 0.0;
330				shadow += textureProjLod(sampler2DShadow(shadow_atlas_texture, shadow_sampler), shadow_uv - shadow_pixel_size * 6.0, 0.0).x;
331				shadow += textureProjLod(sampler2DShadow(shadow_atlas_texture, shadow_sampler), shadow_uv - shadow_pixel_size * 5.0, 0.0).x;
332				shadow += textureProjLod(sampler2DShadow(shadow_atlas_texture, shadow_sampler), shadow_uv - shadow_pixel_size * 4.0, 0.0).x;
333				shadow += textureProjLod(sampler2DShadow(shadow_atlas_texture, shadow_sampler), shadow_uv - shadow_pixel_size * 3.0, 0.0).x;
334				shadow += textureProjLod(sampler2DShadow(shadow_atlas_texture, shadow_sampler), shadow_uv - shadow_pixel_size * 2.0, 0.0).x;
335				shadow += textureProjLod(sampler2DShadow(shadow_atlas_texture, shadow_sampler), shadow_uv - shadow_pixel_size, 0.0).x;
336				shadow += textureProjLod(sampler2DShadow(shadow_atlas_texture, shadow_sampler), shadow_uv, 0.0).x;
337				shadow += textureProjLod(sampler2DShadow(shadow_atlas_texture, shadow_sampler), shadow_uv + shadow_pixel_size, 0.0).x;
338				shadow += textureProjLod(sampler2DShadow(shadow_atlas_texture, shadow_sampler), shadow_uv + shadow_pixel_size * 2.0, 0.0).x;
339				shadow += textureProjLod(sampler2DShadow(shadow_atlas_texture, shadow_sampler), shadow_uv + shadow_pixel_size * 3.0, 0.0).x;
340				shadow += textureProjLod(sampler2DShadow(shadow_atlas_texture, shadow_sampler), shadow_uv + shadow_pixel_size * 4.0, 0.0).x;
341				shadow += textureProjLod(sampler2DShadow(shadow_atlas_texture, shadow_sampler), shadow_uv + shadow_pixel_size * 5.0, 0.0).x;
342				shadow += textureProjLod(sampler2DShadow(shadow_atlas_texture, shadow_sampler), shadow_uv + shadow_pixel_size * 6.0, 0.0).x;
343				shadow /= 13.0;
344			}
345		
346			vec4 shadow_color = unpackUnorm4x8(light_array.data[light_base].shadow_color);
347		#ifdef LIGHT_CODE_USED
348			shadow_color.rgb *= shadow_modulate;
349		#endif
350		
351			shadow_color.a *= light_color.a; //respect light alpha
352		
353			return mix(light_color, shadow_color, shadow);
354		}
355		
356		void light_blend_compute(uint light_base, vec4 light_color, inout vec3 color) {
357			uint blend_mode = light_array.data[light_base].flags & LIGHT_FLAGS_BLEND_MASK;
358		
359			switch (blend_mode) {
360				case LIGHT_FLAGS_BLEND_MODE_ADD: {
361					color.rgb += light_color.rgb * light_color.a;
362				} break;
363				case LIGHT_FLAGS_BLEND_MODE_SUB: {
364					color.rgb -= light_color.rgb * light_color.a;
365				} break;
366				case LIGHT_FLAGS_BLEND_MODE_MIX: {
367					color.rgb = mix(color.rgb, light_color.rgb, light_color.a);
368				} break;
369			}
370		}
371		
372		#endif
373		
374		float msdf_median(float r, float g, float b, float a) {
375			return min(max(min(r, g), min(max(r, g), b)), a);
376		}
377		
378		void main() {
379			vec4 color = color_interp;
380			vec2 uv = uv_interp;
381			vec2 vertex = vertex_interp;
382		
383		#if !defined(USE_ATTRIBUTES) && !defined(USE_PRIMITIVE)
384		
385		#ifdef USE_NINEPATCH
386		
387			int draw_center = 2;
388			uv = vec2(
389					map_ninepatch_axis(pixel_size_interp.x, abs(draw_data.dst_rect.z), draw_data.color_texture_pixel_size.x, draw_data.ninepatch_margins.x, draw_data.ninepatch_margins.z, int(draw_data.flags >> FLAGS_NINEPATCH_H_MODE_SHIFT) & 0x3, draw_center),
390					map_ninepatch_axis(pixel_size_interp.y, abs(draw_data.dst_rect.w), draw_data.color_texture_pixel_size.y, draw_data.ninepatch_margins.y, draw_data.ninepatch_margins.w, int(draw_data.flags >> FLAGS_NINEPATCH_V_MODE_SHIFT) & 0x3, draw_center));
391		
392			if (draw_center == 0) {
393				color.a = 0.0;
394			}
395		
396			uv = uv * draw_data.src_rect.zw + draw_data.src_rect.xy; //apply region if needed
397		
398		#endif
399			if (bool(draw_data.flags & FLAGS_CLIP_RECT_UV)) {
400				uv = clamp(uv, draw_data.src_rect.xy, draw_data.src_rect.xy + abs(draw_data.src_rect.zw));
401			}
402		
403		#endif
404		
405		#ifndef USE_PRIMITIVE
406			if (bool(draw_data.flags & FLAGS_USE_MSDF)) {
407				float px_range = draw_data.ninepatch_margins.x;
408				float outline_thickness = draw_data.ninepatch_margins.y;
409				//float reserved1 = draw_data.ninepatch_margins.z;
410				//float reserved2 = draw_data.ninepatch_margins.w;
411		
412				vec4 msdf_sample = texture(sampler2D(color_texture, texture_sampler), uv);
413				vec2 msdf_size = vec2(textureSize(sampler2D(color_texture, texture_sampler), 0));
414				vec2 dest_size = vec2(1.0) / fwidth(uv);
415				float px_size = max(0.5 * dot((vec2(px_range) / msdf_size), dest_size), 1.0);
416				float d = msdf_median(msdf_sample.r, msdf_sample.g, msdf_sample.b, msdf_sample.a) - 0.5;
417		
418				if (outline_thickness > 0) {
419					float cr = clamp(outline_thickness, 0.0, px_range / 2) / px_range;
420					float a = clamp((d + cr) * px_size, 0.0, 1.0);
421					color.a = a * color.a;
422				} else {
423					float a = clamp(d * px_size + 0.5, 0.0, 1.0);
424					color.a = a * color.a;
425				}
426			} else if (bool(draw_data.flags & FLAGS_USE_LCD)) {
427				vec4 lcd_sample = texture(sampler2D(color_texture, texture_sampler), uv);
428				if (lcd_sample.a == 1.0) {
429					color.rgb = lcd_sample.rgb * color.a;
430				} else {
431					color = vec4(0.0, 0.0, 0.0, 0.0);
432				}
433			} else {
434		#else
435			{
436		#endif
437				color *= texture(sampler2D(color_texture, texture_sampler), uv);
438			}
439		
440			uint light_count = (draw_data.flags >> FLAGS_LIGHT_COUNT_SHIFT) & 0xF; //max 16 lights
441			bool using_light = light_count > 0 || canvas_data.directional_light_count > 0;
442		
443			vec3 normal;
444		
445		#if defined(NORMAL_USED)
446			bool normal_used = true;
447		#else
448			bool normal_used = false;
449		#endif
450		
451			if (normal_used || (using_light && bool(draw_data.flags & FLAGS_DEFAULT_NORMAL_MAP_USED))) {
452				normal.xy = texture(sampler2D(normal_texture, texture_sampler), uv).xy * vec2(2.0, -2.0) - vec2(1.0, -1.0);
453				if (bool(draw_data.flags & FLAGS_FLIP_H)) {
454					normal.x = -normal.x;
455				}
456				if (bool(draw_data.flags & FLAGS_FLIP_V)) {
457					normal.y = -normal.y;
458				}
459				normal.z = sqrt(max(0.0, 1.0 - dot(normal.xy, normal.xy)));
460				normal_used = true;
461			} else {
462				normal = vec3(0.0, 0.0, 1.0);
463			}
464		
465			vec4 specular_shininess;
466		
467		#if defined(SPECULAR_SHININESS_USED)
468		
469			bool specular_shininess_used = true;
470		#else
471			bool specular_shininess_used = false;
472		#endif
473		
474			if (specular_shininess_used || (using_light && normal_used && bool(draw_data.flags & FLAGS_DEFAULT_SPECULAR_MAP_USED))) {
475				specular_shininess = texture(sampler2D(specular_texture, texture_sampler), uv);
476				specular_shininess *= unpackUnorm4x8(draw_data.specular_shininess);
477				specular_shininess_used = true;
478			} else {
479				specular_shininess = vec4(1.0);
480			}
481		
482		#if defined(SCREEN_UV_USED)
483			vec2 screen_uv = gl_FragCoord.xy * canvas_data.screen_pixel_size;
484		#else
485			vec2 screen_uv = vec2(0.0);
486		#endif
487		
488			vec3 light_vertex = vec3(vertex, 0.0);
489			vec2 shadow_vertex = vertex;
490		
491			{
492				float normal_map_depth = 1.0;
493		
494		#if defined(NORMAL_MAP_USED)
495				vec3 normal_map = vec3(0.0, 0.0, 1.0);
496				normal_used = true;
497		#endif
498		
499		#CODE : FRAGMENT
500		
501		#if defined(NORMAL_MAP_USED)
502				normal = mix(vec3(0.0, 0.0, 1.0), normal_map * vec3(2.0, -2.0, 1.0) - vec3(1.0, -1.0, 0.0), normal_map_depth);
503		#endif
504			}
505		
506			if (normal_used) {
507				//convert by item transform
508				normal.xy = mat2(normalize(draw_data.world_x), normalize(draw_data.world_y)) * normal.xy;
509				//convert by canvas transform
510				normal = normalize((canvas_data.canvas_normal_transform * vec4(normal, 0.0)).xyz);
511			}
512		
513			vec4 base_color = color;
514		
515		#ifdef MODE_LIGHT_ONLY
516			float light_only_alpha = 0.0;
517		#elif !defined(MODE_UNSHADED)
518			color *= canvas_data.canvas_modulation;
519		#endif
520		
521		#if defined(USE_LIGHTING) && !defined(MODE_UNSHADED)
522		
523			// Directional Lights
524		
525			for (uint i = 0; i < canvas_data.directional_light_count; i++) {
526				uint light_base = i;
527		
528				vec2 direction = light_array.data[light_base].position;
529				vec4 light_color = light_array.data[light_base].color;
530		
531		#ifdef LIGHT_CODE_USED
532		
533				vec4 shadow_modulate = vec4(1.0);
534				light_color = light_compute(light_vertex, vec3(direction, light_array.data[light_base].height), normal, light_color, light_color.a, specular_shininess, shadow_modulate, screen_uv, uv, base_color, true);
535		#else
536		
537				if (normal_used) {
538					vec3 light_vec = normalize(mix(vec3(direction, 0.0), vec3(0, 0, 1), light_array.data[light_base].height));
539					light_color.rgb = light_normal_compute(light_vec, normal, base_color.rgb, light_color.rgb, specular_shininess, specular_shininess_used);
540				} else {
541					light_color.rgb *= base_color.rgb;
542				}
543		#endif
544		
545				if (bool(light_array.data[light_base].flags & LIGHT_FLAGS_HAS_SHADOW)) {
546					vec2 shadow_pos = (vec4(shadow_vertex, 0.0, 1.0) * mat4(light_array.data[light_base].shadow_matrix[0], light_array.data[light_base].shadow_matrix[1], vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0))).xy; //multiply inverse given its transposed. Optimizer removes useless operations.
547		
548					vec4 shadow_uv = vec4(shadow_pos.x, light_array.data[light_base].shadow_y_ofs, shadow_pos.y * light_array.data[light_base].shadow_zfar_inv, 1.0);
549		
550					light_color = light_shadow_compute(light_base, light_color, shadow_uv
551		#ifdef LIGHT_CODE_USED
552							,
553							shadow_modulate.rgb
554		#endif
555					);
556				}
557		
558				light_blend_compute(light_base, light_color, color.rgb);
559		#ifdef MODE_LIGHT_ONLY
560				light_only_alpha += light_color.a;
561		#endif
562			}
563		
564			// Positional Lights
565		
566			for (uint i = 0; i < MAX_LIGHTS_PER_ITEM; i++) {
567				if (i >= light_count) {
568					break;
569				}
570				uint light_base = draw_data.lights[i >> 2];
571				light_base >>= (i & 3) * 8;
572				light_base &= 0xFF;
573		
574				vec2 tex_uv = (vec4(vertex, 0.0, 1.0) * mat4(light_array.data[light_base].texture_matrix[0], light_array.data[light_base].texture_matrix[1], vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0))).xy; //multiply inverse given its transposed. Optimizer removes useless operations.
575				vec2 tex_uv_atlas = tex_uv * light_array.data[light_base].atlas_rect.zw + light_array.data[light_base].atlas_rect.xy;
576				vec4 light_color = textureLod(sampler2D(atlas_texture, texture_sampler), tex_uv_atlas, 0.0);
577				vec4 light_base_color = light_array.data[light_base].color;
578		
579		#ifdef LIGHT_CODE_USED
580		
581				vec4 shadow_modulate = vec4(1.0);
582				vec3 light_position = vec3(light_array.data[light_base].position, light_array.data[light_base].height);
583		
584				light_color.rgb *= light_base_color.rgb;
585				light_color = light_compute(light_vertex, light_position, normal, light_color, light_base_color.a, specular_shininess, shadow_modulate, screen_uv, uv, base_color, false);
586		#else
587		
588				light_color.rgb *= light_base_color.rgb * light_base_color.a;
589		
590				if (normal_used) {
591					vec3 light_pos = vec3(light_array.data[light_base].position, light_array.data[light_base].height);
592					vec3 pos = light_vertex;
593					vec3 light_vec = normalize(light_pos - pos);
594		
595					light_color.rgb = light_normal_compute(light_vec, normal, base_color.rgb, light_color.rgb, specular_shininess, specular_shininess_used);
596				} else {
597					light_color.rgb *= base_color.rgb;
598				}
599		#endif
600				if (any(lessThan(tex_uv, vec2(0.0, 0.0))) || any(greaterThanEqual(tex_uv, vec2(1.0, 1.0)))) {
601					//if outside the light texture, light color is zero
602					light_color.a = 0.0;
603				}
604		
605				if (bool(light_array.data[light_base].flags & LIGHT_FLAGS_HAS_SHADOW)) {
606					vec2 shadow_pos = (vec4(shadow_vertex, 0.0, 1.0) * mat4(light_array.data[light_base].shadow_matrix[0], light_array.data[light_base].shadow_matrix[1], vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0))).xy; //multiply inverse given its transposed. Optimizer removes useless operations.
607		
608					vec2 pos_norm = normalize(shadow_pos);
609					vec2 pos_abs = abs(pos_norm);
610					vec2 pos_box = pos_norm / max(pos_abs.x, pos_abs.y);
611					vec2 pos_rot = pos_norm * mat2(vec2(0.7071067811865476, -0.7071067811865476), vec2(0.7071067811865476, 0.7071067811865476)); //is there a faster way to 45 degrees rot?
612					float tex_ofs;
613					float distance;
614					if (pos_rot.y > 0) {
615						if (pos_rot.x > 0) {
616							tex_ofs = pos_box.y * 0.125 + 0.125;
617							distance = shadow_pos.x;
618						} else {
619							tex_ofs = pos_box.x * -0.125 + (0.25 + 0.125);
620							distance = shadow_pos.y;
621						}
622					} else {
623						if (pos_rot.x < 0) {
624							tex_ofs = pos_box.y * -0.125 + (0.5 + 0.125);
625							distance = -shadow_pos.x;
626						} else {
627							tex_ofs = pos_box.x * 0.125 + (0.75 + 0.125);
628							distance = -shadow_pos.y;
629						}
630					}
631		
632					distance *= light_array.data[light_base].shadow_zfar_inv;
633		
634					//float distance = length(shadow_pos);
635					vec4 shadow_uv = vec4(tex_ofs, light_array.data[light_base].shadow_y_ofs, distance, 1.0);
636		
637					light_color = light_shadow_compute(light_base, light_color, shadow_uv
638		#ifdef LIGHT_CODE_USED
639							,
640							shadow_modulate.rgb
641		#endif
642					);
643				}
644		
645				light_blend_compute(light_base, light_color, color.rgb);
646		#ifdef MODE_LIGHT_ONLY
647				light_only_alpha += light_color.a;
648		#endif
649			}
650		#endif
651		
652		#ifdef MODE_LIGHT_ONLY
653			color.a *= light_only_alpha;
654		#endif
655		
656			frag_color = color;
657		}
658		
659		
          RDShaderFile                                    RSRC