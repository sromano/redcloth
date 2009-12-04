/*
 * redcloth_scan.rl
 *
 * Copyright (C) 2009 Jason Garber
 */
%%{

  machine redcloth_scan;

  # blocks
  noparagraph_line_start = " "+ ;
  pre_tag_start = "<pre" [^>]* ">" (space* code_tag_start)? ;
  pre_tag_end = (code_tag_end space*)? "</pre>" LF? ;
  pre_block_start = ( "pre" >A %{ STORE("type"); } A C :> "." ( "." %extend | "" ) " " ) %SET_ATTR ;  
  non_ac_btype = ( "pre" );
  btype = (alpha alnum*) -- (non_ac_btype | "fn" digit+);
  block_start = ( btype >A %{ STORE("type"); } A C :> "." ( "." %extend | "" ) " "+ ) >B %{ STORE_B("fallback"); } %SET_ATTR ;
  all_btypes = btype | non_ac_btype;
  next_block_start = ( all_btypes A_noactions C_noactions :> "."+ " " ) >A @{ fexec(reg); } ;
  double_return = LF [ \t]* LF ;
  block_end = ( double_return | EOF );
  ftype = ( "fn" >A %{ STORE("type"); } digit+ >A %{ STORE("id"); } ) ;
  ul = "*" %{NEST(); SET_LIST_TYPE("ul");};
  ol = "#" %{NEST(); SET_LIST_TYPE("ol");};
  ul_start  = ( ul | ol )* ul A_HLGN_noactions* C_noactions :> " "+ ;
  ol_start  = ( ul | ol )* ol N A_HLGN_noactions* C_noactions :> " "+ ;
  list_start  = " "* A_HLGN* C ( ul_start | ol_start ) >B >{RESET_NEST();} @{ fexec(bck); } ;
  
  dt_start = "-" . " "+ ;
  dd_start = ":=" ;
  long_dd  = dd_start " "* LF %{ ADD_BLOCK(); ASET("type", "dd"); } any+ >A %{ TRANSFORM("text"); } :>> "=:" ;
  dl_start = (dt_start mtext (LF dt_start mtext)* " "* dd_start)  ;
  blank_line = LF;
  link_alias = ( "[" >{ ASET("type", "ignore"); } %A chars %T "]" %A uri %{ STORE_URL("href"); } ) ;
  horizontal_rule = '*'{3,} | '-'{3,} | '_'{3,} ;

  pre_tag := |*
    pre_tag_end         { CAT(block); DONE(block); fgoto main; };
    default => esc_pre;
  *|;
  
  pre_block := |*
    EOF { ADD_BLOCKCODE(); fgoto main; };
    double_return when extended { ADD_EXTENDED_BLOCKCODE(); };
    double_return when not_extended { ADD_BLOCKCODE(); fgoto main; } ;
    double_return next_block_start when extended { ADD_EXTENDED_BLOCKCODE(); END_EXTENDED(); fgoto main; };
    double_return next_block_start when not_extended { ADD_BLOCKCODE(); fgoto main; };
    default => esc_pre;
  *|;

  noparagraph_line := |*
    LF  { ADD_BLOCK(); fgoto main; };
    default => esc;
  *|;
  
  block := |*
    EOF { ADD_BLOCK(); fgoto main; };
    double_return when extended { ADD_EXTENDED_BLOCK(); };
    double_return when not_extended { ADD_BLOCK(); fgoto main; };
    double_return next_block_start when extended { ADD_EXTENDED_BLOCK(); END_EXTENDED(); fgoto main; };
    double_return next_block_start when not_extended { ADD_BLOCK(); fgoto main; };
    LF list_start { ADD_BLOCK(); CLEAR_LIST(); LIST_LAYOUT(); fgoto list_item; };
    
    default => esc;
  *|;
 
  ul_item  = ( ul | ol )* ul A_HLGN* C :> " "+ ;
  ol_item  = ( ul | ol )* ol N_noactions A_HLGN* C :> " "+ ;
  list_item  := (" "* ( ul_item | ol_item )) @{ SET_ATTRIBUTES(); fgoto list_content; } ;
  
  list_content := |*
    LF list_start { ADD_BLOCK(); LIST_LAYOUT(); fgoto list_item; };
    block_end     { ADD_BLOCK(); RESET_NEST(); LIST_LAYOUT(); fgoto main; };
    default => esc;
  *|;

  dl := |*
    LF dt_start     { ADD_BLOCK(); ASET("type", "dt"); };
    dd_start        { ADD_BLOCK(); ASET("type", "dd"); };
    long_dd         { INLINE(html, "dd"); CLEAR_REGS(); };
    block_end       { ADD_BLOCK(); INLINE(html, "dl_close");  fgoto main; };
    default => esc;
  *|;

  main := |*
    noparagraph_line_start  { ASET("type", "ignored_line"); fgoto noparagraph_line; };    
    pre_tag_start       { ASET("type", "notextile"); CAT(block); fgoto pre_tag; };
    pre_block_start { fgoto pre_block; };
    block_start     { fgoto block; };
    horizontal_rule { INLINE(html, "hr"); };
    list_start      { CLEAR_LIST(); LIST_LAYOUT(); fgoto list_item; };
    dl_start        { fexec(ts + 1); INLINE(html, "dl_open"); ASET("type", "dt"); fgoto dl; };
    link_alias      { STORE_LINK_ALIAS(); DONE(block); };
    blank_line => cat;
    default => esc;
    default
    { 
      CLEAR_REGS();
      RESET_TYPE();
      CAT(block);
      fgoto block;
    };
    EOF;
  *|;

}%%;
