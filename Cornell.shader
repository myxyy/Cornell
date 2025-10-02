Shader "myxy/Cornell"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _LightPos ("Light Position", Vector) = (0, 0.5, 0, 1)
        _BallPos ("Ball Position", Vector) = (1, 0.5, 1, 1)
        _MirrorPos ("Mirror Position", Vector) = (-1, 0.5, -1, 1)
        _Mirror2Pos ("Mirror2 Position", Vector) = (-1, 0.5, 1, 1)
        _GlassPos ("Glass Position", Vector) = (1, 0.5, -1, 1)
        _LightIntensity ("Light Intensity", Range(0, 1)) = 1
    }
    SubShader
    {
        Cull Front
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            // Upgrade NOTE: excluded shader from OpenGL ES 2.0 because it uses non-square matrices
            #pragma exclude_renderers gles
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 wpos : TEXCOORD1;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            struct ray
            {
                float3 origin;
                float3 direction;
            };

            struct hit
            {
                float3 position;
                float3 normal;
                float4 material;
            };

            static int light_id = 0;
            static int lambert_id = 1;
            static int mirror_id = 2;
            static int glass_id = 3;
            static int anti_glass_id = 4;

            static hit none = {(float3)1e6, float3(0,0,0), float4(0,0,0,-1)};

            float4 _LightPos;
            float4 _BallPos;
            float4 _MirrorPos;
            float4 _Mirror2Pos;
            float4 _GlassPos;
            float _LightIntensity;

            hit sphere(float3 center, float radius, ray r, float4 material, bool reverse=false)
            {
                float3 oc = r.origin - center;
                float a = dot(r.direction, r.direction);
                float b = 2.0 * dot(oc, r.direction);
                float c = - radius * radius + dot(oc, oc);
                float discriminant = b * b - 4 * a * c;
                hit h = none;
                if (discriminant > 0 && (radius - distance(r.origin, center)) * (reverse ? -1 : 1) < 0)
                {
                    float t = (-b - sqrt(discriminant) * (reverse ? -1 : 1)) / (2.0 * a);
                    if (t > 0)
                    {
                        h.position = r.origin + t * r.direction;
                        h.normal = normalize(h.position - center) * (reverse ? -1 : 1);
                        h.material = material;
                    }
                }
                return h;
            }

            // returns a hit record for the nearest intersection with the box
            hit box(float3 bmin, float3 bmax, ray r, float4 material)
            {
                hit h = none;
                float3 rd = rcp(r.direction);
                float3 tmin = (bmin - r.origin) * rd;
                float3 tmax = (bmax - r.origin) * rd;
                float3 t1 = min(tmin, tmax);
                float3 t2 = max(tmin, tmax);
                float t_near = max(max(t1.x, t1.y), t1.z);
                float t_far = min(min(t2.x, t2.y), t2.z);
                if (t_near < t_far && t_far > 0)
                {
                    h.position = t_near * r.direction + r.origin;
                    // compute normal
                    float3 p = h.position;
                    if      (abs(p.x - bmin.x) < 1e-4) h.normal = float3(-1,0,0);
                    else if (abs(p.x - bmax.x) < 1e-4) h.normal = float3(1,0,0);
                    else if (abs(p.y - bmin.y) < 1e-4) h.normal = float3(0,-1,0);
                    else if (abs(p.y - bmax.y) < 1e-4) h.normal = float3(0,1,0);
                    else if (abs(p.z - bmin.z) < 1e-4) h.normal = float3(0,0,-1);
                    else if (abs(p.z - bmax.z) < 1e-4) h.normal = float3(0,0,1);
                    else h.normal = float3(0,0,0);
                    h.material = material;
                }
                return h;
            }

            hit box_by_center_size(float3 center, float3 size, ray r, float4 material)
            {
                return box(center - size * 0.5, center + size * 0.5, r, material);
            }

            hit comp(hit h1, hit h2, ray r)
            {
                float3 d1 = h1.position - r.origin;
                float3 d2 = h2.position - r.origin;
                if (dot(d1, d1) < dot(d2, d2))
                {
                    return h1;
                }
                else
                {
                    return h2;
                }
            }

            hit plane(float3 p0, float3 n, ray r, float4 material)
            {
                hit h = none;
                float denom = dot(n, r.direction);
                if (denom < 0)
                {
                    float t = dot(p0 - r.origin, n) / denom;
                    h.position = r.origin + t * r.direction;
                    h.normal = n;
                    h.material = material;
                }
                return h;
            }

            hit world(ray r)
            {
                float3 baige = float3(0.9,0.8,0.7);
                float3 white = float3(1,1,1);
                hit h = sphere(_LightPos.xyz, 0.5, r, float4(white,light_id + 0.999));
                h = comp(h, sphere(_BallPos.xyz, 0.5, r, float4(white,lambert_id)), r);
                h = comp(h, sphere(_MirrorPos.xyz, 0.5, r, float4(white,mirror_id)), r);
                h = comp(h, sphere(_Mirror2Pos.xyz, 0.5, r, float4(1,0.2,0.2,mirror_id)), r);
                h = comp(h, sphere(_GlassPos.xyz, 0.5, r, float4(0.8,0.9,1.0,glass_id)), r);
                h = comp(h, sphere(_GlassPos.xyz, 0.5, r, float4(white,anti_glass_id), true), r);
                h = comp(h, box(float3(-1,3.9,-1), float3(1,4,1), r, float4(white,light_id + min(_LightIntensity, 0.999))), r);
                h = comp(h, box_by_center_size(float3(0,0.25,1), float3(1,0.5,2), r, float4(1,1,1,lambert_id)), r);
                h = comp(h, box_by_center_size(float3(0,0.25,0.8), float3(1.1,0.6,1.6), r, float4(1,0.5,0.5,lambert_id)), r);
                h = comp(h, plane(float3(0,0,0), float3(0,1,0), r, float4(baige,lambert_id)), r);
                h = comp(h, plane(float3(0,4,0), float3(0,-1,0), r, float4(baige,lambert_id)), r);
                h = comp(h, plane(float3(2,0,0), float3(-1,0,0), r, float4(1,0.2,0.2,lambert_id)), r);
                h = comp(h, plane(float3(-2,0,0), float3(1,0,0), r, float4(0.2,0.2,1,lambert_id)), r);
                h = comp(h, plane(float3(0,0,2), float3(0,0,-1), r, float4(baige,lambert_id)), r);
                h = comp(h, plane(float3(0,0,-2), float3(0,0,1), r, float4(baige,lambert_id)), r);
                return h;
            }

            v2f vert (appdata v)
            {
                v2f o;
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.wpos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            struct frag_out
            {
                float4 color : SV_Target;
                float depth : SV_Depth;
            };

            float2 f3h2(float3 p)
            {
                return frac(sin(mul(float2x3(
                    12.9898, 78.233, 37.719,
                    93.9898, 67.345, 45.719
                ), p)) * float2(43758.5453, 24634.6345));
            }

            float f3h1(float3 p)
            {
                return frac(sin(dot(p, float3(12.9898, 78.233, 37.719))) * 43758.5453);
            }

            // two uniform randoms to a direction on the unit sphere
            float3 h2d3(float2 p)
            {
                float z = p.x * 2 - 1;
                float r = sqrt(1 - z * z);
                float phi = p.y * 2 * UNITY_PI;
                return float3(r * cos(phi), r * sin(phi), z);
            }

            float3 f3d3(float3 p)
            {
                return h2d3(f3h2(p));
            }

            #define REFLECT_COUNT 8

            float3 trace(ray r, float seed=0)
            {
                hit h;
                float k = 2e-3;
                float3 albedo_list[REFLECT_COUNT];
                float3 light_list[REFLECT_COUNT];
                for (int i=0; i<REFLECT_COUNT; i++)
                {
                    h = world(r);
                    h.position = floor(h.position / k) * k;

                    albedo_list[i] = h.material.xyz;
                    light_list[i] = float3(0,0,0);
                    float3 next_dir = r.direction;
                    if (floor(h.material.w) == light_id)
                    {
                        light_list[i] = h.material.xyz * frac(h.material.w);
                        h.material.w = lambert_id;
                    }
                    if (h.material.w == glass_id || h.material.w == anti_glass_id)
                    {
                        float refraction_index = h.material.w == glass_id ? 1.5 : 1.0/1.5;
                        next_dir = refract(r.direction, h.normal, 1/refraction_index);
                    }
                    if (h.material.w == mirror_id)
                    {
                        next_dir = reflect(r.direction, h.normal);
                    }
                    if (h.material.w == lambert_id)
                    {
                        float3 rand_dir = f3d3(seed * 0.12345 + h.position);
                        if (f3h1(h.position + seed * .5255) < 0.75)
                        {
                            float3 light_pos = (f3h1(h.position + seed * .52626) < _LightIntensity ? float3(0,4,0) : _LightPos.xyz) + rand_dir;
                            rand_dir = normalize(light_pos - h.position);
                        }
                        //if (f3h1(h.position + seed * .5255) < 0.1) rand_dir = normalize(_LightPos + rand_dir - h.position);
                        float dot_r_n = dot(rand_dir, h.normal);
                        next_dir = rand_dir + 2 * saturate(-dot_r_n) * h.normal;
                        albedo_list[i] *= dot(next_dir, h.normal) * 2;
                    }

                    float3 eps = h.normal * 2 * k;
                    r.origin = h.position - eps * sign(dot(r.direction, next_dir));
                    r.direction = next_dir;
                }

                float3 light = float3(0,0,0);
                for (int j=REFLECT_COUNT-1; j>=0; j--)
                {
                    light *= albedo_list[j];
                    light += light_list[j];
                }
                return light;
            }

            #define NUM_RAYS 1

            frag_out frag (v2f i)
            {
                frag_out o;

                ray r;
                r.origin = _WorldSpaceCameraPos;
                r.direction = normalize(i.wpos - _WorldSpaceCameraPos);

                hit depth = world(r);
                float4 clipPos = UnityObjectToClipPos(mul(unity_WorldToObject, float4(depth.position,1.0)));
                o.depth = clipPos.z / clipPos.w;

                float3 color = float3(0,0,0);
                for (int j=0; j<NUM_RAYS; j++)
                {
                    color += trace(r, j);
                }
                o.color = float4(saturate(color / NUM_RAYS), 1.0);

                return o;
            }
            ENDCG
        }
    }
}
