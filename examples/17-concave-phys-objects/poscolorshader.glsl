---VERTEX SHADER---
#ifdef GL_ES
    precision highp float;
#endif

/* Outputs to the fragment shader */
varying vec4 frag_color;

/* vertex attributes */
attribute vec2     pos;
attribute vec4     v_color;


/* uniform variables */
uniform mat4       modelview_mat;
uniform mat4       projection_mat;
uniform vec4       color;
uniform float      opacity;

void main (void) {
  frag_color = v_color*color;
  vec4 pos = vec4(pos.xy, 0.0, 1.0);
  gl_Position = projection_mat * modelview_mat * pos;

}


---FRAGMENT SHADER---
#ifdef GL_ES
    precision highp float;
#endif

/* Outputs from the vertex shader */
varying vec4 frag_color;

void main (void){
    gl_FragColor = frag_color;
}
