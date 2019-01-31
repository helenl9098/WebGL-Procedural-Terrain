#version 300 es


uniform mat4 u_Model;
uniform mat4 u_ModelInvTr;
uniform mat4 u_ViewProj;
uniform vec2 u_PlanePos; // Our location in the virtual world displayed by the plane
uniform int u_Time;

in vec4 vs_Pos;
in vec4 vs_Nor;
in vec4 vs_Col;

out vec3 fs_Pos;
out vec4 fs_Nor;
out vec4 fs_Col;

out float fs_Sine;

float random1( vec2 p , vec2 seed) {
  return fract(sin(dot(p + seed, vec2(127.1, 311.7))) * 43758.5453);
}

float random1( vec3 p , vec3 seed) {
  return fract(sin(dot(p + seed, vec3(987.654, 123.456, 531.975))) * 85734.3545);
}

vec2 random2( vec2 p , vec2 seed) {
  return fract(sin(vec2(dot(p + seed, vec2(311.7, 127.1)), dot(p + seed, vec2(269.5, 183.3)))) * 85734.3545);
}

float worley3D(vec3 p)
{                    
  float r = 3.0;
    vec3 f = floor(p);
    vec3 x = fract(p);
  for(int i = -1; i<=1; i++)
  {
    for(int j = -1; j<=1; j++)
    {
      for(int k = -1; k<=1; k++)
      {
          vec3 seed = vec3(3.0, 2.0, 2.0);
          vec3 q = vec3(float(i),float(j),float(k));
          vec3 v = q + vec3(random1((q+f)*1.11, seed), 
                            random1((q+f)*1.14, seed), 
                            random1((q+f)*1.17, seed)) - x;
          float d = dot(v, v);
          r = min(r, d);
      }
    }
  }
    return sqrt(r);
} 

float noise(vec2 st) {
	vec2 i = floor(st);
	vec2 f = fract(st);
	vec2 seed = vec2(10, 20);

	float a = random1(i, seed);
	float b = random1(i + vec2(1.0, 0.0), seed);
	float c = random1(i + vec2(0.0, 1.0), seed);
	float d = random1(i + vec2(1.0, 1.0), seed);

	vec2 u = f * f * (3.0 - 2.0 * f);

	return mix(a, b, u.x)  +
            (c - a)* u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
    p /= 28.0;
	// Initial values
    float value = 0.0;
    float amplitude = .5;
    float frequency = 0.;
    
	// Loop of octaves
    for (int i = 0; i < 6; i++) {
        value += amplitude * noise(p);
        p *= 2.;
        amplitude *= .5;
    }

    return value;
}

//Based off of iq's described here: http://www.iquilezles.org/www/articles/voronoilin
float voronoi(vec2 p) {
    vec2 n = floor(p);
    vec2 f = fract(p);
    float md = 5.0;
    vec2 m = vec2(0.0);
    for (int i = -1;i<=1;i++) {
        for (int j = -1;j<=1;j++) {
            vec2 g = vec2(i, j);
            vec2 o = random2(n+g, vec2(100., 100.));
            o = 0.5+0.5*sin(float(u_Time) / 80.0 +5.038*o);
            vec2 r = g + o - f;
            float d = dot(r, r);
            if (d<md) {
              md = d;
              m = n+g+o;
            }
        }
    }
    return md;
}

float ov(vec2 p) {
    float v = 0.0;
    float a = 0.4;
    for (int i = 0;i<3;i++) {
        v+= voronoi(p)*a;
        p*=2.0;
        a*=0.5;
    }
    return v;
}

vec2 rigidTransform(vec2 p, float theta, float scale, vec2 t) {
    float c = cos(theta), s = sin(theta);
    return scale * (mat2(c, s, -s, c) * p) + t;
}

float fbm2(vec2 p) {
    p /= 28.0;
  // Initial values
    float value = 0.0;
    float amplitude = .5;
    float frequency = 0.;
    float shift = float(10);
    
  // Loop of octaves
    for (int i = 0; i < 3; i++) {
        value += pow(.5, float(i+1)) * ov(p);
        p = rigidTransform(p, .5, 2., vec2(1e3));
    }

    return value;
}

vec4 water(vec2 pos2d) {
  vec4 a = vec4(214, 255, 252, 1.0) / 255.;
  vec4 b = vec4(237, 255, 252, 1.0) / 255.;
  vec4 mix1 = mix(a, b, smoothstep(0.0, 0.85, ov(pos2d / 1.7)));

  vec4 e1 = vec4(208, 224, 222, 1.0) / 255.;
  vec4 f1 = vec4(229, 252, 250, 1.0) / 255.;
  vec4 mix2 = mix(e1, f1, smoothstep(0.0, 0.85, ov(pos2d / 1.5)));

  float fbmvalue = fbm(pos2d * 2.0);
  return vec4(mix(mix1, mix2, fbmvalue));
}

vec4 algae(vec2 pos2d, float fbm_noise) {

    float normalized = (fbm_noise - 0.35) * 10.0;
    float f = worley3D(vec3(pos2d * 0.2, float(u_Time) / 400.0));

    vec4 a = vec4(143, 188, 165, 1.0) / 255.;
    vec4 b = water(pos2d);
    vec4 mix1 = mix(a, b, smoothstep(0.0, 0.6, f));
    return vec4(mix(b, mix1, smoothstep(0.0, 1.6, normalized)));   
}

vec4 lowlandscolor(vec2 pos2d, float fbm_noise) {
    float normalized = (fbm_noise - 0.45) * 10.0;
    float f = worley3D(vec3(pos2d * 0.14, 1.0));
    vec4 a = vec4(197, 198, 186, 1.0) / 255.;
    vec4 b = algae(pos2d, fbm_noise);
    if (f > 0.60) {
      return b;
    } 
    else if (f > 0.58) {
      return mix(vec4(144, 139, 121, 0) / 255., b, normalized);
      //return vec4(144, 139, 121, 0) / 255.;
    }
    else {
      vec4 c = vec4(144, 139, 121, 1.0) / 255.;

      // first layer of FBM Mix
      float p1 = fbm(pos2d * 4.);
      vec4 e1 = vec4(171, 181, 161, 1.0) / 255.;
      vec4 f1 = vec4(198, 255, 226, 1.0) / 255.;
      vec4 d1 = mix(e1, f1, smoothstep(0.0, 1.0, p1 * 1.4));


      // second layer of FBM Mix
      float p2 = fbm(pos2d * 5.);
      float p3= fbm(pos2d * 7.);
      vec4 d2 = mix(vec4(p2), d1, smoothstep(0.0, 1.0, p3));


      // mix stone color with moss color
      vec4 mix1 = mix(d2, c, smoothstep(0.0, 0.7, f * f));
      float m = worley3D(vec3(pos2d * 0.18, 1.0));
      vec4 mix3 = mix(vec4(198, 255, 226, 1.0) / 255., vec4(98, 117, 104, 1.0) / 255., smoothstep(0.2, 0.5, m));

      vec4 mix2 = mix(mix3, mix1, smoothstep(0.0, 0.5, m));

      vec4 mix4 = mix(mix2, mix1, smoothstep(0.0, 1.0, f));
      vec4 mix5 = mix(vec4(98, 117, 104, 0) / 255., mix4, smoothstep(0.6, 1.0, 
                                          pow(normalized, 0.2)));
      return mix(mix5, vec4(229, 252, 250, 1) / 255.0, pow(normalized, 1.5));

    }
}

float lowlandsheight(vec2 pos2d, float fbm_noise) {
  float normalized = (fbm_noise - 0.45) * 10.0;
  float f = worley3D(vec3(pos2d * 0.14, 1.0));
  if (f > 0.58) {
    return 2.;
  } 
    return 2.0 + smoothstep(0.0, 1.0, normalized);
  

}


void main()
{
  fs_Pos = vs_Pos.xyz;
  vec2 pos2d = vec2(vs_Pos.x + u_PlanePos.x, vs_Pos.z + u_PlanePos.y) + vec2(30, 100.0);
  vec3 pos3d = vec3(vs_Pos.x + u_PlanePos.x, 2.0, vs_Pos.z + u_PlanePos.y);
  fs_Sine = (sin((vs_Pos.x + u_PlanePos.x) * 3.14159 * 0.1) + cos((vs_Pos.z + u_PlanePos.y) * 3.14159 * 0.1));
  //vec4 modelposition = vec4(vs_Pos.x, fs_Sine * 2.0, vs_Pos.z, 1.0);
  vec4 modelposition = vec4(vs_Pos.x , 2.0, vs_Pos.z, 1.0);
  
  // fbm noise value 
  float fbm_noise = fbm(pos2d);
  
  fs_Col = vec4(fbm_noise);

//========================================================
  // this is the Hill ish area
  if (fbm_noise > 0.58) {
    float height = (fbm_noise - 0.5) * 2.0;
    
    float mountaintexture = fbm(pos2d * 7.0);
    float mountaintexture1 = fbm(pos2d * 10.0);
    float mountainheight = (fs_Sine * 2.0 + 5.0) * (height + 1.0) * height * (height + 1.0);

    mountaintexture = mountaintexture + mountainheight / 15.0;
    vec4 bluemix = mix(vec4(1, 1, 1, 1), vec4(4, 42, 68, 1) / 255., mountaintexture);
    vec4 greenmix = mix(vec4(0, 127, 118, 1) / 255., vec4(235, 252, 194, 1) / 255., mountaintexture1);
    
    vec4 bluegreenmix = mix(greenmix, bluemix, mountaintexture);
    fs_Col = bluegreenmix;

    modelposition = vec4(vs_Pos.x, (pow(mountainheight * 800.0, 0.4)) - 10.0, vs_Pos.z, 1.0);
  } 
  else if (fbm_noise > 0.56) {
    float height = floor((fbm_noise - 0.5) * 2.0 * 20.0);
    height = smoothstep(0.0, 0.7, height / 20.0);
    float normalizedf = (fbm_noise - 0.56) * 50.0;
    float newHeight = smoothstep(lowlandsheight(pos2d, fbm_noise),
                                  7.0 + pow(height + 1.0, 2.0),
                                  pow(normalizedf, 0.2));
    fs_Col = vec4(229, 252, 250, 1) / 255.0;
  }
  
//========================================================
  // this is the Low lands
  else if (fbm_noise > 0.45) {
    float lowlandsheight = lowlandsheight(pos2d, fbm_noise);
    // if (lowlandsheight > 2.0) {
    //   fs_Col = vec4(1 , 0, 0, 0);
    // }
    // else {
    fs_Col = lowlandscolor(pos2d, fbm_noise); 
    //}
    modelposition = vec4(vs_Pos.x , lowlandsheight, vs_Pos.z, 1.0);
  }
  else if (fbm_noise > 0.35) {
    fs_Col = algae(pos2d, fbm_noise);
  }

//========================================================
  // this is the ponds
  else {
    fs_Col = water(pos2d);
  }
  modelposition = u_Model * modelposition;
  gl_Position = u_ViewProj * modelposition;
}
