RSRC                    RDShaderFile            ��������                                                  resource_local_to_scene    resource_name    bytecode_vertex    bytecode_fragment    bytecode_tesselation_control     bytecode_tesselation_evaluation    bytecode_compute    compile_error_vertex    compile_error_fragment "   compile_error_tesselation_control %   compile_error_tesselation_evaluation    compile_error_compute    script 
   _versions    base_error           local://RDShaderSPIRV_nlkqa ;         local://RDShaderFile_10lo5 YR         RDShaderSPIRV          �O  #    &             1        GLSL.std.450                     main    /   8   N   \   }             !  $  %          @              �       main     
    get_omni_attenuation(f1;f1;f1;    	   distance      
   inv_range        decay        nd    ,   voxel_index   /   gl_GlobalInvocationID     6   Params    6       grid_size     6      max_cascades      6      cascade   6      light_count   6      process_offset    6      process_increment     6      probe_axis_size   6      bounce_feedback   6      y_mult    6   	   use_occlusion     8   params    L   DispatchData      L       x     L      y     L      z     L      total_count   N   dispatch_data     W   voxel_position    X   ProcessVoxel      X       position      X      albedo    X      light     X      light_aniso   Z   ProcessVoxels     Z       data      \   process_voxels    c   positioni     q   position      x   CascadeData   x       offset    x      to_cell   x      probe_world_offset    x      pad   x      pad2      {   Cascades      {       data      }   cascades      �   voxel_albedo      �   albedo    �   light_accum   �   valid_aniso   �   rgbe      �   r     �   g     �   b     �   e     �   m     �   l     �   aniso     �   i     �   strength      �   pos_to_uvw       uvw_ofs     i       attenuation     light_distance      Light           color          energy         direction          has_shadow         position           attenuation        type           cos_spot_angle   	      inv_spot_attenuation        	   radius      Lights          data        lights      direction     $  rel_vec   <  param     >  param     ?  param     D  rel_vec   Y  param     [  param     \  param     `  cos_spot_angle    e  cos_angle     r  scos      v  spot_rim      �  hit   �  ray_pos   �  ray_dir   �  inv_dir   �  cell_size     �  j     �  pos   �  local_distance    �  t0    �  t1    �  tmax      �  max_advance   �  advance   �  occlusion       uvw   	  distance        sdf_cascades        linear_sampler    U  light     b  j     |  indexable     �  light_total   �  i     �  lumas     �  luma_total    �  cRed      �  cGreen    �  cBlue     �  cMax      �  expp      �  sMax      �  exps      �  sRed      �  sGreen    �  sBlue       light_total_rgbe        dst_light       dst_aniso0    !  dst_aniso1    $  lightprobe_texture    %  occlusion_texture   G  /         H  6       #       H  6      #      H  6      #      H  6      #      H  6      #      H  6      #      H  6      #       H  6      #   $   H  6      #   (   H  6   	   #   ,   G  6      H  L          H  L          H  L       #       H  L         H  L         H  L      #      H  L         H  L         H  L      #      H  L         H  L         H  L      #      G  L      G  N   "       G  N   !      H  X       #       H  X      #      H  X      #      H  X      #      G  Y         H  Z          H  Z          H  Z       #       G  Z      G  \   "       G  \   !      H  x       #       H  x      #      H  x      #      H  x      #      H  x      #       G  z      0   H  {       #       G  {      G  }   "       G  }   !      H        #       H       #      H       #      H       #      H       #       H       #   ,   H       #   0   H       #   4   H       #   8   H    	   #   <   G       @   H           H           H        #       G       G    "       G    !   	   G    "       G    !      G    "       G    !      G  |     G          G    "       G    !      G       G    "       G    !      G       G  !  "       G  !  !      G  !     G  $  "       G  $  !   
   G  %  "       G  %  !           !                             !                 +          �?+            +     "   ��8  *              +      *     -   *         .      -   ;  .   /      +  *   0          1      *     4           5            6   4   *   *   *   *   *   5         *      7   	   6   ;  7   8   	   +  5   9         :   	   *   +  *   =        >   +  5   F        L   *   *   *   *      M      L   ;  M   N      +  5   O         P      *     X   *   *   *   *     Y   X     Z   Y      [      Z   ;  [   \      +  5   ]         a   5         b      a   +  *   h      +  *   i      ,  -   j   0   h   i   +  *   l      ,  -   m   l   l   l      p      4   +     t      ?,  4   u   t   t   t     w           x   4      a   *   w   +  *   y        z   x   y     {   z      |      {   ;  |   }      +  5   ~      +  5   �         �            �      4   +  5   �   
   +  *   �      ,  -   �   �   �   �   +     �     �A+  *   �        �   4   �      �      �   ,  4   �            , 	 �   �   �   �   �   �   �   �   +  5   �      +  *   �   ?   +  *   �   �   +  5   �      +  *   �   �  +  5   �      +  5   �      +     �      @+     �     pA+     �     A+  *   �         �   	   4   +       �x�`    4      4   *   4      *                                  ;         +  5                4      .  	      +  5   6  	      7        +  5   b     +     �  o�:   �     >   *  >   �  +     �  ���>+     �  ���>  �  >      +  *   �      	 
                               
  y              ;                   
                 ;              
  +         C)  >   "     a     5   ,  4   s           ,  4   t           ,  4   u           +     v    ��,  4   w  v        ,  4   x     v     ,  4   y        v  , 	 �   z  s  t  u  w  x  y    �     �      �     �  +     �   �G+     �    ��+     �  r1?+     �     D+  5        +  5        +  *     @   ,  -       =   =    	   *                     !              ;           	                                      ;           	                                       ;     !       	 "                             #      "  ;  #  $      ;    %      6               �     ;  +   ,      ;  +   W      ;  b   c      ;  p   q      ;  +   �      ;  p   �      ;  �   �      ;  +   �      ;  +   �      ;     �      ;     �      ;     �      ;     �      ;     �      ;  p   �      ;  +   �      ;  +   �      ;     �      ;  p   �      ;  p         ;  +        ;          ;          ;  p        ;  p   $     ;     <     ;     >     ;     ?     ;  p   D     ;     Y     ;     [     ;     \     ;     `     ;     e     ;     r     ;     v     ;  �  �     ;  p   �     ;  p   �     ;  p   �     ;     �     ;  +   �     ;  p   �     ;     �     ;  p   �     ;  p   �     ;  p   �     ;     �     ;     �     ;     �     ;  p        ;     	     ;  p   U     ;  a  b     ;  �   |     z  ;  p   �     ;  a  �     ;  �  �     ;     �     ;     �     ;     �     ;     �     ;     �     ;     �     ;     �     ;     �     ;     �     ;     �     ;     �     ;  +        A  1   2   /   0   =  *   3   2   >  ,   3   A  :   ;   8   9   =  *   <   ;   �  >   ?   <   =   �  A       �  ?   @   A   �  @   A  :   B   8   9   =  *   C   B   =  *   D   ,   �  *   E   D   C   >  ,   E   A  :   G   8   F   =  *   H   G   =  *   I   ,   �  *   J   I   H   >  ,   J   �  A   �  A   =  *   K   ,   A  P   Q   N   O   =  *   R   Q   �  >   S   K   R   �  U       �  S   T   U   �  T   �  �  U   =  *   ^   ,   A  P   _   \   ]   ^   ]   =  *   `   _   >  W   `   =  *   d   W   =  *   e   W   =  *   f   W   P  -   g   d   e   f   �  -   k   g   j   �  -   n   k   m   |  a   o   n   >  c   o   =  a   r   c   o  4   s   r   �  4   v   s   u   >  q   v   A  :      8   ~   =  *   �      A  �   �   }   ]   �   �   =     �   �   =  4   �   q   P  4   �   �   �   �   �  4   �   �   �   >  q   �   A  :   �   8   ~   =  *   �   �   A  �   �   }   ]   �   ]   =  4   �   �   =  4   �   q   �  4   �   �   �   >  q   �   =  *   �   ,   A  P   �   \   ]   �   �   =  *   �   �   >  �   �   =  *   �   �   �  *   �   �   �   =  *   �   �   �  *   �   �   9   =  *   �   �   P  -   �   �   �   �   �  -   �   �   �   p  4   �   �   P  4   �   �   �   �   �  4   �   �   �   >  �   �   >  �   �   =  *   �   �   �  *   �   �   �   �  *   �   �   �   >  �   �   =  *   �   ,   A  P   �   \   ]   �   ~   =  *   �   �   >  �   �   =  *   �   �   �  *   �   �   �   �  *   �   �   �   p     �   �   >  �   �   =  *   �   �   �  *   �   �   �   �  *   �   �   �   p     �   �   >  �   �   =  *   �   �   �  *   �   �   �   �  *   �   �   �   �  *   �   �   �   p     �   �   >  �   �   =  *   �   �   �  *   �   �   �   �  *   �   �   �   p     �   �   >  �   �   =     �   �   �     �   �   �   �     �   �   �        �         �   �   >  �   �   =     �   �   =     �   �   =     �   �   P  4   �   �   �   �   =     �   �   �  4   �   �   �   >  �   �   =  *   �   ,   A  P   �   \   ]   �   O   =  *   �   �   >  �   �   >  �   0   �  �   �  �   �  �   �       �  �   �  �   =  *   �   �   �  >   �   �   �   �  �   �   �   �  �   =  *   �   �   =  *   �   �   �  *   �   �   �   �  *   �   �   �   �  *   �   �   �   p     �   �   �     �   �   �   >  �   �   =  *   �   �   =  4   �   �   =     �   �   �  4   �   �   �   A  p   �   �   �   =  4   �   �   �  4   �   �   �   A  p   �   �   �   >  �   �   �  �   �  �   =  *   �   �   �  *   �   �   �   >  �   �   �  �   �  �   A  �   �   8   ]   =  4   �   �   P  4   �            �  4   �   �   �   >  �   �   =  4     �   �  4       t   >       >    0   �    �    �          �    �    =  *   	    A  :   
  8   O   =  *     
  �  >     	    �        �    >       >      =  *       A  P       ]       =  *       �        � 	                     �    =  *       A         ]     ~   =  4   !       4   "  !  >    "  �    �    =  *   %    A    &    ]   %  F   =  4   '  &  =  4   (  q   �  4   )  '  (  >  $  )  =  4   *  $    4   +     E   *  >    +  =  4   ,  $       -     B   ,  >    -  A  .  /  8   �   =     0  /  A     1  $  =   =     2  1  �     3  2  0  A     4  $  =   >  4  3  =  *   5    A  7  8    ]   5  6  =     9  8  �     :     9  =  *   ;    =     =    >  <  =  >  >  :  A  7  @    ]   ;  9   =     A  @  >  ?  A  9     B     <  >  ?  >    B  �    �    =  *   E    A    F    ]   E  F   =  4   G  F  =  4   H  q   �  4   I  G  H  >  D  I  =  4   J  D    4   K     E   J  >    K  =  4   L  D       M     B   L  >    M  A  .  N  8   �   =     O  N  A     P  D  =   =     Q  P  �     R  Q  O  A     S  D  =   >  S  R  =  *   T    A  7  U    ]   T  6  =     V  U  �     W     V  =  *   X    =     Z    >  Y  Z  >  [  W  A  7  ]    ]   X  9   =     ^  ]  >  \  ^  9     _     Y  [  \  >    _  =  *   a    A  7  c    ]   a  b  =     d  c  >  `  d  =  4   f      4   g  f  =  *   h    A    i    ]   h  ~   =  4   j  i  �     k  g  j  >  e  k  =     l  e  =     m  `  �  >   n  l  m  �  p      �  n  o  p  �  o  �    �  p  =     s  e  =     t  `       u     (   s  t  >  r  u  =     w  r  �     x     w  =     y  `  �     z     y  �     {  x  z       |     (   "   {  >  v  |  =     }  v  =  *   ~    A  7      ]   ~  �   =     �         �        }  �  �     �     �  =     �    �     �  �  �  >    �  �    �    =     �    �  >   �  �  �  �  �      �  �  �  �  �  �  �    �  �  >  �  �  =  4   �  q   >  �  �  =  4   �    >  �  �  =  4   �  �  P  4   �           �  4   �  �  �  >  �  �  A  :   �  8   ~   =  *   �  �  A  �   �  }   ]   �  �   =     �  �  �     �     �  >  �  �  =  4   �      4   �        �  =     �  �  �  4   �  �  �  �  4   �  �  �  =  4   �  �  �  4   �  �  �  >  �  �  =  4   �  �  �  4   �  �  �  =     �  �  �  4   �  �  �  =  4   �  �  �  4   �  �  �  >  �  �  A  :   �  8   ~   =  *   �  �  >  �  �  �  �  �  �  �  �  �      �  �  �  �  =  *   �  �  A  :   �  8   �   =  *   �  �  �  >   �  �  �  �  �  �  �  �  �  =  4   �  �  =  *   �  �  A  �   �  }   ]   �  ]   =  4   �  �  �  4   �  �  �  >  �  �  =  *   �  �  A  �   �  }   ]   �  �   =     �  �  =  4   �  �  �  4   �  �  �  >  �  �  =     �    =  *   �  �  A  �   �  }   ]   �  �   =     �  �  �     �  �  �  >  �  �  =  4   �  �  �  �  �  �  �   �  >   �  �  �  >   �  �  �  �      �  �  �  �  �  �  =  4   �  �  A  �   �  8   ]   =  4   �  �  �  �  �  �  �  �  >   �  �  �  �  �  �  �  >   �  �  �  �  �  �  �      �  �  �  �  �  �  �  �  �  �  =  4   �  �    4   �  �  =  4   �  �  �  4   �  �  �  >  �  �  A  �   �  8   ]   =  4   �  �  =  4   �  �  �  4   �  �  �  =  4   �  �  �  4   �  �  �  >  �  �  =  4   �  �  =  4   �  �    4   �     (   �  �  >  �  �  A     �  �  0   =     �  �  A     �  �  =   =     �  �  A     �  �  �  =     �  �       �     %   �  �       �     %   �  �  >  �  �  =     �  �  =     �  �       �     %   �  �  >  �  �  >  �     >  �     �  �  �  �  �  �  �      �  �  �  �  =     �  �  =     �  �  �  >      �  �  �     �  �  �  �  =  4     �  =  4     �  =       �  �  4         �  4         =  4     �   �  4         >      =  *     �  A          =  
      =        V          =  4       X  w               Q             �           �            >  	    =       	  �  >       �  �  !      �       !  �     >  �  "  �  �  �  !  =     $  �  =     %  	       &     %   $  %  >  �  &  =     '  	  =     (  �  �     )  (  '  >  �  )  �  �  �  �  �  �  �  �  =  >   *  �  �  ,      �  *  +  ,  �  +  =     -  �  =     .    �     /  .  -  >    /  �  �  �  ,  =     1  �  =     2  �  �  >   3  1  2  �  5      �  3  4  5  �  4  �  �  �  5  =  4   7  �  =     8  �  �  4   9  7  8  =  4   :  �  �  4   ;  :  9  >  �  ;  =  *   <  �  A  �   =  }   ]   <  �   =     >  =  =  4   ?  �  P  4   @  >  >  >  �  4   A  ?  @  >  �  A  =  *   B  �  A  �   C  }   ]   B  ]   =  4   D  C  =  4   E  �  �  4   F  E  D  >  �  F  =     G  �  =  *   H  �  A  �   I  }   ]   H  �   =     J  I  �     K  G  J  =     L    �     M  L  K  >    M  =  4   N  �  >  �  N  �  �  �  �  =  *   O  �  �  *   P  O  �   >  �  P  �  �  �  �  =  >   Q  �  �  >   R  Q  �  T      �  R  S  T  �  S  =  4   V  �   =  *   W    A    X    ]   W  ]   =  4   Y  X  �  4   Z  V  Y  =  *   [    A  7  \    ]   [  �   =     ]  \  �  4   ^  Z  ]  =     _    �  4   `  ^  _  >  U  `  >  b  ]   �  c  �  c  �  e  f      �  g  �  g  =  5   h  b  �  >   i  h    �  i  d  e  �  d  =  *   j  �   =  5   k  b  �  5   l  �   k  |  *   m  l  �  *   n  j  m  �  >   o  n  0   �  q      �  o  p  q  �  p  =  5   r  b  =  5   {  b  A  p   }  |  {  =  4   ~  }  =  4       �     �  ~         �     (      �  =  4   �  U  �  4   �  �  �  A  p   �  �   r  =  4   �  �  �  4   �  �  �  A  p   �  �   r  >  �  �  �  q  �  q  �  f  �  f  =  5   �  b  �  5   �  �  �   >  b  �  �  c  �  e  �  T  �  T  �    �    =  *   �    �  *   �  �  �   >    �  �    �    >  �  �   >  �  ]   �  �  �  �  �  �  �      �  �  �  �  =  5   �  �  �  >   �  �    �  �  �  �  �  �  =  5   �  �  A  p   �  �   �  =  4   �  �  =  4   �  �  �  4   �  �  �  >  �  �  =  5   �  �  =  5   �  �  A     �  �   �  0   =     �  �  =  5   �  �  A     �  �   �  =   =     �  �  =  5   �  �  A     �  �   �  �  =     �  �       �     (   �  �       �     (   �  �  A     �  �  �  >  �  �  �  �  �  �  =  5   �  �  �  5   �  �  �   >  �  �  �  �  �  �  A     �  �  0   =     �  �  A     �  �  =   =     �  �  A     �  �  �  =     �  �       �     (   �  �       �     (   �  �  >  �  �  A     �  �  0   =     �  �       �     +   �     �  >  �  �  A     �  �  =   =     �  �       �     +   �     �  >  �  �  A     �  �  �  =     �  �       �     +   �     �  >  �  �  =     �  �  =     �  �  =     �  �       �     (   �  �       �     (   �  �  >  �  �  =     �  �       �        �  �     �  �  �       �        �       �     (   �  �  �     �  �     �     �  �  �   >  �  �  =     �  �  =     �  �  �     �  �  �   �     �  �  �        �        �   �  �     �  �  �  �     �  �  t        �        �  >  �  �  =     �  �  �     �  �     >  �  �  =     �  �  �  >   �     �  =     �  �  �  >   �  �  �  �  >   �  �  �  �  �      �  �  �  �  �  �  =     �  �  >  �  �  �  �  �  �  =     �  �  =     �  �  �     �  �  �   �     �  �  �        �        �   �  �     �  �  �  �     �  �  t        �        �  >  �  �  =     �  �  =     �  �  �     �  �  �   �     �  �  �        �        �   �  �     �  �  �  �     �  �  t        �        �  >  �  �  =     �  �  =     �  �  �     �  �  �   �     �  �  �        �        �   �  �     �  �  �  �        �  t                   >  �    =       �  m  *       �  *       �   =       �  m  *       �  *       �   �  *   	    6  �  *   
    	  =       �  m  *       �  *       �   �  *         �  *     
    =       �  m  *       �  *       �   �  *         �  *         >      �  8  6               7     	   7     
   7        �     ;           =        	   =        
   �              >        =           =           �              >        =           =           �              >        =           �                         (         >        =           =           �              >        =            =     !   	        #      (   !   "   =     $           %   $        &         #   %   �     '       &   �  '   8           RDShaderFile                                    RSRC