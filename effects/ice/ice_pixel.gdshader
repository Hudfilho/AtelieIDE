shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float age : hint_range(0.0, 12.0) = 0.4;
uniform float burst_duration = 0.9;
uniform float frozen_duration = 2.5;
uniform float melt_duration = 1.6;
uniform int layer : hint_range(0, 1) = 1; // 0 = ground, 1 = wind and shards
uniform float pixel_resolution : hint_range(16.0, 128.0, 1.0) = 64.0;
uniform float variation = 0.0;
uniform float ground_opacity : hint_range(0.0, 1.0) = 0.22;
uniform vec4 white_color : source_color = vec4(0.92, 1.0, 1.0, 1.0);
uniform vec4 frost_color : source_color = vec4(0.53, 0.90, 1.0, 1.0);
uniform vec4 ice_color : source_color = vec4(0.22, 0.61, 0.83, 1.0);
uniform vec4 deep_color : source_color = vec4(0.12, 0.32, 0.52, 1.0);

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise_value(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f*f*(3.0-2.0*f);
    return mix(mix(hash(i), hash(i+vec2(1.0,0.0)),f.x),
        mix(hash(i+vec2(0.0,1.0)),hash(i+vec2(1.0)),f.x),f.y);
}

void fragment() {
    vec2 p = ((floor(UV*pixel_resolution)+0.5)/pixel_resolution-0.5)*2.0;
    float r = length(p);
    float a = atan(p.y,p.x);
    float t = clamp(age/max(burst_duration,0.01),0.0,1.0);
    float frame = floor(t*18.0);
    vec2 seed = vec2(variation*1.31, variation*0.73);
    vec4 col = vec4(0.0);
    if (layer == 0) {
        float melt = clamp((age-burst_duration-frozen_duration)/max(melt_duration,0.01),0.0,1.0);
        float n = noise_value(p*7.0+seed);
        float edge = noise_value(p*4.0+seed+8.0);
        float growth = 1.0-pow(1.0-clamp(t*1.5,0.0,1.0),3.0);
        float radius = (0.08+growth*0.57)*(1.0-melt*0.75);
        float mask = step(r, radius+(edge-0.5)*0.16);
        // Melt the edges and open pixel-sized holes, rather than fading to blur.
        mask *= step(melt*1.1,n);
        mask *= step(0.002,age)*(1.0-step(0.999,melt));
        vec2 cell_p = p*6.0+seed;
        vec2 cell = floor(cell_p);
        vec2 f = fract(cell_p);
        float nearest = 10.0;
        float second = 10.0;
        float tile = 0.0;
        for(int y=-1;y<=1;y++) {
            for(int x=-1;x<=1;x++) {
                vec2 offset = vec2(float(x),float(y));
                vec2 id = cell+offset;
                vec2 point = vec2(hash(id),hash(id+19.3));
                float d = length(offset+point-f);
                if(d<nearest) {
                    second=nearest;
                    nearest=d;
                    tile=hash(id+42.0);
                } else { second=min(second,d); }
            }
        }
        col=deep_color;
        if(tile>0.27) { col=ice_color; }
        if(tile>0.72) { col=frost_color; }
        // Facet boundaries look like white-blue cracks inside the ice sheet.
        if(second-nearest<0.046) { col=frost_color; }
        if(second-nearest<0.017 && n>0.40) { col=white_color; }
        if(abs(r-radius-(edge-0.5)*0.16)<0.027) { col=frost_color; }
        // Tiny travelling glints while the floor stays frozen.
        float glint=hash(floor(p*25.0)+floor(age*5.0)+seed);
        if(glint>0.994 && melt<0.7) { col=white_color; }
        float highlight = second-nearest<0.046 ? 1.45 : 1.0;
        col.a*=mask*min(ground_opacity*highlight,1.0);
    } else {
        float dispersal=smoothstep(0.48,1.0,t);
        float remnants=1.0-smoothstep(0.56,0.99,t);
        float expansion=1.0-pow(1.0-t,2.4);
        float radius=0.06+expansion*0.78;
        float n=noise_value(p*9.0+seed+vec2(frame*0.5,-frame*0.3));
        float ring_d=abs(r-radius-(n-0.5)*0.07);
        float gap=sin(a*7.0-frame*0.7+variation);
        float live=step(0.001,age)*(1.0-step(1.0,t));
        float wind=step(ring_d,(0.035*(1.0-t)+0.012)*remnants)*step(-0.45,gap);
        float white=step(ring_d,0.013*remnants)*step(0.15,gap);
        // Long, rotating scythe-shaped gusts sweep through the damage area.
        float phase=fract((a + r*(2.8-dispersal*1.8) - t*11.0 + variation)*0.63662);
        float taper=smoothstep(0.16,0.70,r/max(radius,0.01));
        float blade_width=mix(0.25,0.035,taper)*remnants;
        float envelope=step(radius*mix(0.16,0.80,dispersal),r)*step(r,radius*1.06);
        float blade=step(phase,blade_width)*envelope;
        float blade_core=step(phase,blade_width*0.22)*envelope;
        float blade_shadow=step(phase,blade_width+0.045*remnants)*envelope;
        float frost=max(wind,blade);
        white=max(white,blade_core);
        float blue=blade_shadow;
        // Counter-swept narrow ribbons add speed between the main gusts.
        float spiral=sin(a*3.0+r*12.0-t*24.0+variation);
        float ribbon=step(mix(0.94,1.0,dispersal),spiral)*step(radius*mix(0.30,0.82,dispersal),r)*step(r,radius*0.98);
        frost=max(frost,ribbon);
        // Advected holes split the wind ribbons into drifting pixel fragments.
        float erosion=noise_value(p*22.0+seed-vec2(t*9.0,t*4.0));
        float shred=step(dispersal*0.94,erosion);
        blue*=shred;
        frost*=shred;
        white*=shred;
        for(int i=0;i<28;i++) {
            float fi=float(i);
            float h=hash(vec2(fi+variation,38.2));
            float angle=fi*2.399963+variation+t*(1.5+h*1.2);
            vec2 dir=vec2(cos(angle),sin(angle));
            vec2 side=vec2(-dir.y,dir.x);
            vec2 center=dir*(0.06+expansion*(0.60+h*0.24)+dispersal*0.055);
            center+=side*dispersal*(h-0.5)*0.12;
            vec2 rel=p-center;
            vec2 q=vec2(dot(rel,dir),dot(rel,side));
            float particle_end=0.80+h*0.19;
            float shrink=1.0-smoothstep(0.49+h*0.10,particle_end,t);
            float length_shard=max(0.001,(0.105+h*0.075)*(1.0-t*0.35)*shrink);
            // Slanted ice needles and bright elongated tips.
            q.y+=q.x*0.40;
            float diamond=abs(q.x)/length_shard+abs(q.y)/max(0.001,0.022*shrink);
            float particle_live=step(0.06+h*0.10,t)*(1.0-step(particle_end,t));
            if(i<20) {
                blue=max(blue,step(diamond,1.35)*particle_live);
                frost=max(frost,step(diamond,1.0)*particle_live);
                white=max(white,step(diamond,0.46)*particle_live);
            } else {
                vec2 sq=abs(rel);
                float snow=max(step(sq.x,0.012*shrink)*step(sq.y,0.045*shrink),step(sq.y,0.012*shrink)*step(sq.x,0.045*shrink));
                white=max(white,snow*particle_live);
            }
        }
        col=ice_color;
        if(frost>0.0) { col=frost_color; }
        if(white>0.0) { col=white_color; }
        col.a*=max(blue,max(frost,white))*live;
    }
    COLOR=col;
}
