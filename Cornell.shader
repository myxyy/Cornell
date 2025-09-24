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
    }
    SubShader
    {
        Cull Front
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
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
                int material_id;
            };

            static int light_id = 0;
            static int red_id = 1;
            static int blue_id = 2;
            static int gray_id = 3;
            static int mirror_id = 4;
            static int mirror2_id = 5;
            static int glass_id = 6;
            static int anti_glass_id = 7;

            static hit none = {float3(0,0,0), float3(0,0,0), -1};

            float4 _LightPos;
            float4 _BallPos;
            float4 _MirrorPos;
            float4 _Mirror2Pos;
            float4 _GlassPos;

            hit sphere(float3 center, float radius, ray r, int material_id)
            {
                if (distance(r.origin, center) < radius)
                {
                    return none;
                }
                float3 oc = r.origin - center;
                float a = dot(r.direction, r.direction);
                float b = 2.0 * dot(oc, r.direction);
                float c = dot(oc, oc) - radius * radius;
                float discriminant = b * b - 4 * a * c;
                if (discriminant > 0)
                {
                    hit h;
                    float t = (-b - sqrt(discriminant)) / (2.0 * a);
                    if (t < 0)
                    {
                        return none;
                    }
                    h.position = r.origin + t * r.direction;
                    h.normal = normalize(h.position - center);
                    h.material_id = material_id;
                    return h;
                }
                return none;
            }

            hit anti_sphere(float3 center, float radius, ray r, int material_id)
            {
                if (distance(r.origin, center) > radius)
                {
                    return none;
                }
                float3 oc = r.origin - center;
                float a = dot(r.direction, r.direction);
                float b = 2.0 * dot(oc, r.direction);
                float c = dot(oc, oc) - radius * radius;
                float discriminant = b * b - 4 * a * c;
                if (discriminant > 0)
                {
                    hit h;
                    float t = (-b + sqrt(discriminant)) / (2.0 * a);
                    if (t < 0)
                    {
                        return none;
                    }
                    h.position = r.origin + t * r.direction;
                    h.normal = -normalize(h.position - center);
                    h.material_id = material_id;
                    return h;
                }
                return none;
            }

            // returns a hit record for the nearest intersection with the box
            hit box(float3 bmin, float3 bmax, ray r, int material_id)
            {
                hit h;
                float3 tmin = (bmin - r.origin) / r.direction;
                float3 tmax = (bmax - r.origin) / r.direction;
                float3 t1 = min(tmin, tmax);
                float3 t2 = max(tmin, tmax);
                float t_near = max(max(t1.x, t1.y), t1.z);
                float t_far = min(min(t2.x, t2.y), t2.z);
                if (t_near > t_far || t_far < 0)
                {
                    return none;
                }
                else
                {
                    float t = t_near >= 0 ? t_near : t_far;
                    h.position = r.origin + t * r.direction;
                    // compute normal
                    float3 p = h.position;
                    if (abs(p.x - bmin.x) < 1e-4) h.normal = float3(-1,0,0);
                    else if (abs(p.x - bmax.x) < 1e-4) h.normal = float3(1,0,0);
                    else if (abs(p.y - bmin.y) < 1e-4) h.normal = float3(0,-1,0);
                    else if (abs(p.y - bmax.y) < 1e-4) h.normal = float3(0,1,0);
                    else if (abs(p.z - bmin.z) < 1e-4) h.normal = float3(0,0,-1);
                    else if (abs(p.z - bmax.z) < 1e-4) h.normal = float3(0,0,1);
                    else h.normal = float3(0,0,0);
                }
                h.material_id = material_id;
                return h;
            }

            hit box_by_center_size(float3 center, float3 size, ray r, int material_id)
            {
                return box(center - size * 0.5, center + size * 0.5, r, material_id);
            }

            bool is_hit(hit h)
            {
                return length(h.normal) > 0;
            }

            hit comp(hit h1, hit h2, ray r)
            {
                bool hit1 = is_hit(h1);
                bool hit2 = is_hit(h2);
                if (hit1 && hit2)
                {
                    if (distance(h1.position, r.origin) < distance(h2.position, r.origin))
                    {
                        return h1;
                    }
                    else
                    {
                        return h2;
                    }
                }
                else if (hit1)
                {
                    return h1;
                }
                else
                {
                    return h2;
                }
            }

            hit plane(float3 p0, float3 n, ray r, int material_id)
            {
                hit h;
                float denom = dot(n, r.direction);
                if (denom < 0)
                {
                    float t = dot(p0 - r.origin, n) / denom;
                    if (t >= 0)
                    {
                        h.position = r.origin + t * r.direction;
                        h.normal = n;
                        h.material_id = material_id;
                        return h;
                    }
                }
                return none;
            }

            hit world(ray r)
            {
                hit h = sphere(_LightPos.xyz, 0.5, r, light_id);
                h = comp(h, sphere(_BallPos.xyz, 0.5, r, gray_id), r);
                h = comp(h, sphere(_MirrorPos.xyz, 0.5, r, mirror_id), r);
                h = comp(h, sphere(_Mirror2Pos.xyz, 0.5, r, mirror2_id), r);
                h = comp(h, sphere(_GlassPos.xyz, 0.5, r, glass_id), r);
                h = comp(h, anti_sphere(_GlassPos.xyz, 0.5, r, anti_glass_id), r);
                h = comp(h, box(float3(-1,3.9,-1), float3(1,4,1), r, light_id), r);
                h = comp(h, box_by_center_size(float3(0,0.25,1), float3(1,0.5,2), r, gray_id), r);
                h = comp(h, plane(float3(0,0,0), float3(0,1,0), r, gray_id), r);
                h = comp(h, plane(float3(0,4,0), float3(0,-1,0), r, gray_id), r);
                h = comp(h, plane(float3(2,0,0), float3(-1,0,0), r, red_id), r);
                h = comp(h, plane(float3(-2,0,0), float3(1,0,0), r, blue_id), r);
                h = comp(h, plane(float3(0,0,2), float3(0,0,-1), r, gray_id), r);
                h = comp(h, plane(float3(0,0,-2), float3(0,0,1), r, gray_id), r);
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

            float4 trace_body(ray r, out ray out_r)
            {
                hit depth = world(r);
                float4 col = float4(1,1,1,1);
                out_r = r;
                if (is_hit(depth))
                {
                    if (depth.material_id == red_id)
                    {
                        col *= float4(1,0.2,0.2,1);
                    }
                    else if (depth.material_id == blue_id)
                    {
                        col *= float4(0.2,0.2,1,1);
                    }
                    else if (depth.material_id == gray_id)
                    {
                        col *= float4(0.8,0.8,0.8,1);
                    }
                    else if (depth.material_id == light_id)
                    {
                        return float4(1,1,1,1);
                    }
                    return col;
                }
                else
                {
                    return float4(0,0,0,1);
                }
            }

            float4 trace(ray r, float seed=0)
            {
                hit h;
                float4 albedo = float4(1,1,1,1);
                for (int i=0; i<8; i++)
                {
                    float k = 5e2;
                    //r.origin = floor(r.origin * k) / k;
                    //r.direction = normalize(floor(r.direction * k) / k);
                    h = world(r);
                    h.position = floor(h.position * k) / k;
                    if (is_hit(h))
                    {
                        if (h.material_id == light_id)
                        {
                            return float4(2,2,1,1) * 3 * albedo;
                        }
                        else if (h.material_id == glass_id || h.material_id == anti_glass_id)
                        {
                            float refraction_index = h.material_id == glass_id ? 1.5 : 1.0/1.5;
                            float3 refract_dir = refract(r.direction, h.normal, 1/refraction_index);
                            
                            r.origin = h.position - h.normal * 1e-2;
                            r.direction = refract_dir;
                            //albedo *= float4(0.8,0.9,1.0,1);
                        }
                        else if (h.material_id == mirror_id || h.material_id == mirror2_id)
                        {
                            float3 reflect_dir = reflect(r.direction, h.normal);
                            r.origin = h.position + h.normal * 1e-6;
                            r.direction = reflect_dir;
                            if (h.material_id == mirror2_id)
                            {
                                albedo *= float4(1.0,0.2,0.2,1);
                            }
                        }
                        else
                        {
                            if (h.material_id == red_id)
                            {
                                albedo *= float4(1,0.2,0.2,1);
                            }
                            else if (h.material_id == blue_id)
                            {
                                albedo *= float4(0.2,0.2,1,1);
                            }
                            else if (h.material_id == gray_id)
                            {
                                albedo *= float4(0.8,0.8,0.8,1);
                            }
                            float time = _Time.y * 0;
                            float3 rand = normalize(float3(
                                frac(sin(dot(h.position.xy, float2(12.9898,78.233) + i + seed)) * (44758.5453 + time)),
                                frac(sin(dot(h.position.yz, float2(14.9898,79.233) + i + seed)) * (43758.5453 + time)),
                                frac(sin(dot(h.position.zx, float2(13.9898,77.233) + i + seed)) * (42758.5453 + time))
                            ) * 2 - 1);
                            rand = rand - dot(rand, h.normal) * h.normal + abs(dot(rand, h.normal)) * h.normal;
                            r.origin = h.position + h.normal * 1e-4;
                            r.direction = rand;
                        }
                    }
                    else
                    {
                        return float4(0,0,0,1) * albedo;
                    }
                }
                return float4(0,0,0,1) * albedo;
            }

            frag_out frag (v2f i)
            {
                ray r;
                frag_out o;
                r.origin = _WorldSpaceCameraPos;
                r.direction = normalize(i.wpos - _WorldSpaceCameraPos);
                fixed4 col = tex2D(_MainTex, i.uv);
                hit depth = world(r);
                if (is_hit(depth))
                {
                    col = fixed4(depth.normal * 0.5 + 0.5, 1.0);
                }
                else
                {
                    discard;
                }
                float4 clipPos = UnityObjectToClipPos(mul(unity_WorldToObject, float4(depth.position,1.0)));
                o.depth = clipPos.z / clipPos.w;

                float4 color = float4(0,0,0,1);
                int count = 8;
                for (int j=0; j<count; j++)
                {
                    color += trace(r, j * 0.56365);
                }
                o.color = color / count;
                return o;
            }
            ENDCG
        }
    }
}
