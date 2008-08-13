#! /usr/local/bin/lua-5.1
if arg [ 0 ] then		-- #1
   standalone = 1 		-- #2
end		-- #3
format = string . format 		-- #4
function enter_namespace(name )		-- #5
   local parent = getfenv ( 2 )		-- #6
   local namespace = { parent_globals = parent }		-- #7
   local i , v 		-- #8
   for i , v in pairs ( parent ) do		-- #9
      if i ~= "parent_globals" then		-- #10
         namespace [ i ]= v 		-- #11
      end		-- #12
   end		-- #13
   parent [ name ]= namespace 		-- #14
   namespace [ name ]= namespace 		-- #15
   setfenv ( 2 , namespace )		-- #16
end		-- #17
		-- #18
function exit_namespace()		-- #19
   local parent = getfenv ( 2 )		-- #20
   setfenv ( 2 , parent . parent_globals )		-- #21
end		-- #22
		-- #23
enter_namespace ( "jslua" )		-- #24
local symbols = "~!#%%%^&*()%-%+=|/%.,<>:;\"'%[%]{}%?" 		-- #25
local symbolset = "[" .. symbols .. "]" 		-- #26
local msymbols = "<>!%&%*%-%+%=%|%/%%%^%." 		-- #27
local msymbolset = "[" .. msymbols .. "]" 		-- #28
local nospace = { [ "~" ] = 1 , [ "#" ] = 1 , }		-- #29
local paths = { "" , }		-- #30
function add_path(path )		-- #31
   table . insert ( paths , path )		-- #32
end		-- #33
		-- #34
local loadfile_orig = loadfile 		-- #35
function loadfile(name )		-- #36
   local _ , path 		-- #37
   local module , error 		-- #38
   for _ , path in pairs ( paths ) do		-- #39
      module , error = loadfile_orig ( path .. name )		-- #40
      if module then		-- #41
         setfenv ( module , getfenv ( 2 ) )		-- #42
         break 		-- #43
      end		-- #44
   end		-- #45
   return module , error 		-- #46
end		-- #47
		-- #48
function _message(msg )		-- #49
   io . stderr : write ( msg .. "\n" )		-- #50
end		-- #51
		-- #52
function message(msg )		-- #53
   if verbose then		-- #54
      _message ( msg )		-- #55
   end		-- #56
end		-- #57
		-- #58
function dbgmessage(msg )		-- #59
   if dbgmode then		-- #60
      _message ( msg )		-- #61
   end		-- #62
end		-- #63
		-- #64
function emiterror(msg , source )		-- #65
   local p = "" 		-- #66
   source = source or cursource 		-- #67
   if source then		-- #68
      p = format ( "%s (%d) at token '%s' : " , source . filename , source . nline or - 1 , source . token or "<null>" )		-- #69
   end		-- #70
   _message ( p .. msg )		-- #71
   hasError = 1 		-- #72
   numError = ( numError or 0 )+ 1 		-- #73
end		-- #74
		-- #75
function colapse(t )		-- #76
   local i , n 		-- #77
   while t [ 2 ] do		-- #78
      n = #t 		-- #79
      local t2 = { }		-- #80
      for i = 1 , n , 2 do		-- #81
         table . insert ( t2 , t [ i ] .. ( t [ i + 1 ] or "" ) )		-- #82
      end		-- #83
      t = t2 		-- #84
   end		-- #85
   return t [ 1 ]or "" 		-- #86
end		-- #87
		-- #88
function opensource(realfn , filename )		-- #89
   local source = { }		-- #90
   source . filename = filename 		-- #91
   if standalone then		-- #92
      if realfn then		-- #93
         source . handle = io . open ( filename , "r" )		-- #94
      else		-- #95
         source . handle = io . stdin 		-- #96
      end		-- #97
      if not source . handle then		-- #98
         emiterror ( format ( "Can't open source '%s'" , filename ) )		-- #99
         return nil 		-- #100
      end		-- #101
   else		-- #102
      source . buffer = gBuffer 		-- #103
      source . bufpos = 1 		-- #104
   end		-- #105
   source . nline = 0 		-- #106
   source . ntoken = 0 		-- #107
   source . tokens = { }		-- #108
   source . tokentypes = { }		-- #109
   source . tokenlines = { }		-- #110
   local token = basegettoken ( source )		-- #111
   while token do		-- #112
      table . insert ( source . tokens , token )		-- #113
      table . insert ( source . tokentypes , source . tokentype )		-- #114
      table . insert ( source . tokenlines , source . nline )		-- #115
      source . ntoken = source . ntoken + 1 		-- #116
      token = basegettoken ( source )		-- #117
   end		-- #118
   source . tokenpos = 1 		-- #119
   return source 		-- #120
end		-- #121
		-- #122
function closesource(source )		-- #123
   if standalone then		-- #124
      source . handle : close ( )		-- #125
      source . handle = nil 		-- #126
   end		-- #127
   cursource = nil 		-- #128
end		-- #129
		-- #130
function getline(source )		-- #131
   if standalone then		-- #132
      source . linebuffer = source . handle : read ( "*l" )		-- #133
   else		-- #134
      if not source . bufpos then		-- #135
         return 		-- #136
      end		-- #137
      local i = string . find ( source . buffer , "\n" , source . bufpos )		-- #138
      source . linebuffer = string . sub ( source . buffer , source . bufpos , ( i or 0 ) - 1 )		-- #139
      source . bufpos = i and ( i + 1 )		-- #140
   end		-- #141
   source . nline = source . nline + 1 		-- #142
   source . newline = 1 		-- #143
end		-- #144
		-- #145
function savepos(source )		-- #146
   return source . tokenpos 		-- #147
end		-- #148
		-- #149
function gotopos(source , pos )		-- #150
   source . tokenpos = pos - 1 		-- #151
   return gettoken ( source )		-- #152
end		-- #153
		-- #154
function gettoken(source )		-- #155
   cursource = source 		-- #156
   local pos = source . tokenpos 		-- #157
   local token = source . tokens [ pos ]		-- #158
   source . token = token 		-- #159
   source . tokentype = source . tokentypes [ pos ]		-- #160
   source . nline = source . tokenlines [ pos ]		-- #161
   if not token then		-- #162
      return 		-- #163
   end		-- #164
   source . tokenpos = pos + 1 		-- #165
   dbgmessage ( token )		-- #166
   return token 		-- #167
end		-- #168
		-- #169
function basegettoken(source )		-- #170
   local newline 		-- #171
   local tokens 		-- #172
   if not source . linebuffer then		-- #173
      newline = 1 		-- #174
      getline ( source )		-- #175
      if not source . linebuffer then		-- #176
         return nil 		-- #177
      end		-- #178
   else		-- #179
      source . newline = nil 		-- #180
   end		-- #181
   local i , j 		-- #182
   local s = source . linebuffer 		-- #183
   i = string . find ( s , "%S" )		-- #184
   if not i then		-- #185
      source . linebuffer = nil 		-- #186
      return basegettoken ( source )		-- #187
   end		-- #188
   j = string . find ( s , "[%s" .. symbols .. "]" , i )		-- #189
   if not j then		-- #190
      j = string . len ( s )+ 1 		-- #191
   else		-- #192
      j = j - 1 		-- #193
   end		-- #194
   source . stick = ( i == 1 )		-- #195
   source . tokentype = "word" 		-- #196
   if i ~= j then		-- #197
      local c = string . sub ( s , i , i )		-- #198
      if string . find ( c , symbolset ) then		-- #199
         j = i 		-- #200
         while string . find ( string . sub ( s , j + 1 , j + 1 ) , msymbolset ) and string . find ( c , msymbolset ) do		-- #201
            j = j + 1 		-- #202
         end		-- #203
         source . tokentype = string . sub ( s , i , j )		-- #204
      else		-- #205
         if string . find ( string . sub ( s , j - 1 , j ) , symbolset ) then		-- #206
            j = j - 1 		-- #207
         end		-- #208
      end		-- #209
   end		-- #210
   token = string . sub ( s , i , j )		-- #211
   source . token = token 		-- #212
   source . linebuffer = string . sub ( s , j + 1 )		-- #213
   if token == "\"" or token == "'" then		-- #214
      local t = token 		-- #215
      s = source . linebuffer 		-- #216
      local ok 		-- #217
      while not ok do		-- #218
         local k 		-- #219
         _ , k = string . find ( s , t )		-- #220
         while k and k > 1 do		-- #221
            local l = k - 1 		-- #222
            local n = 0 		-- #223
            while l > 0 and string . sub ( s , l , l ) == "\\" do		-- #224
               l = l - 1 		-- #225
               n = n + 0.5 		-- #226
            end		-- #227
            if n > 0 then		-- #228
               dbgmessage ( format ( "N = %g (%g) '%s'" , n , math . floor ( n ) , source . linebuffer ) )		-- #229
            end		-- #230
            if math . floor ( n ) == n then		-- #231
               break 		-- #232
            end		-- #233
            _ , k = string . find ( s , t , k + 1 )		-- #234
         end		-- #235
         if k then		-- #236
            token = token .. string . sub ( s , 1 , k )		-- #237
            source . linebuffer = string . sub ( s , k + 1 )		-- #238
            dbgmessage ( format ( "TOKEN(%s) REST(%s), k(%d)" , token , source . linebuffer , k + 1 ) )		-- #239
            ok = 1 		-- #240
         else		-- #241
            token = token .. string . sub ( s , 1 , - 2 )		-- #242
            getline ( source )		-- #243
            if not source . linebuffer then		-- #244
               return nil 		-- #245
            end		-- #246
            s = source . linebuffer 		-- #247
         end		-- #248
      end		-- #249
      source . tokentype = t 		-- #250
   end		-- #251
   if token == "//" or ( source . newline and token == "#" ) then		-- #252
      getline ( source )		-- #253
      return basegettoken ( source )		-- #254
   end		-- #255
   if token == "/*" then		-- #256
      local k 		-- #257
      _ , k = string . find ( s , "*/" , j + 2 )		-- #258
      while not k do		-- #259
         getline ( source )		-- #260
         s = source . linebuffer 		-- #261
         if not s then		-- #262
            return nil 		-- #263
         end		-- #264
         _ , k = string . find ( s , "*/" )		-- #265
      end		-- #266
      source . linebuffer = string . sub ( s , k + 1 )		-- #267
      return basegettoken ( source )		-- #268
   end		-- #269
   if source . tokentype == "word" and not string . find ( token , "[^0123456789%.]" ) then		-- #270
      source . tokentype = "number" 		-- #271
      local s = source . linebuffer 		-- #272
      if string . sub ( s , 1 , 1 ) == "." then		-- #273
         local i = string . find ( s , "%D" , 2 )		-- #274
         if i then		-- #275
            source . linebuffer = string . sub ( s , i )		-- #276
            i = i - 1 		-- #277
         else		-- #278
            source . linebuffer = nil 		-- #279
         end		-- #280
         token = token .. string . sub ( s , 1 , i )		-- #281
      end		-- #282
   end		-- #283
   return token 		-- #284
end		-- #285
		-- #286
local exprstack = { }		-- #287
function processaccum(source , token , what )		-- #288
   out ( "= " )		-- #289
   for i = exprstack [ #exprstack ] - 1 , source . tokenpos - 3 , 1 do		-- #290
      out ( source . tokens [ i ] .. " " )		-- #291
   end		-- #292
   out ( string . sub ( what , 1 , 1 ) .. " " )		-- #293
   return token 		-- #294
end		-- #295
		-- #296
function processincr(source , token , what )		-- #297
   processaccum ( source , token , what )		-- #298
   out ( "1 " )		-- #299
   return token 		-- #300
end		-- #301
		-- #302
local exprkeywords = { [ "function" ] = function (source , token , what )		-- #303
   out ( "function " )		-- #304
   if token ~= "(" then		-- #305
      out ( token )		-- #306
      token = gettoken ( source )		-- #307
   end		-- #308
   if token ~= "(" then		-- #309
      emiterror ( "'(' expected" , source )		-- #310
      return token 		-- #311
   end		-- #312
   out ( "(" )		-- #313
   token = processblock ( source , "(" , ")" , 1 )		-- #314
   out ( ")" )		-- #315
   outnl ( )		-- #316
   outindent ( 1 )		-- #317
   token = processstatement ( source , gettoken ( source ) , 1 )		-- #318
   outindent ( - 1 )		-- #319
   outi ( )		-- #320
   out ( "end" )		-- #321
   outnl ( )		-- #322
   gotopos ( source , source . tokenpos - 1 )		-- #323
   return ";" 		-- #324
end		-- #325
, [ "var" ] = "local" , [ "||" ] = "or" , [ "&&" ] = "and" , [ "!=" ] = "~=" , [ "!" ] = "not" , [ "+=" ] = processaccum , [ "-=" ] = processaccum , [ "*=" ] = processaccum , [ "/=" ] = processaccum , [ "++" ] = processincr , [ "--" ] = processincr , }		-- #326
function eatexpr(source , token )		-- #327
   while token and exprkeywords [ token ] do		-- #328
      local expr = exprkeywords [ token ]		-- #329
      if type ( expr ) == "string" then		-- #330
         out ( expr .. " " )		-- #331
         token = gettoken ( source )		-- #332
      else		-- #333
         token = exprkeywords [ token ]( source , gettoken ( source ) , token )		-- #334
      end		-- #335
   end		-- #336
   return token 		-- #337
end		-- #338
		-- #339
function processblock(source , open , close , n )		-- #340
   if n < 1 then		-- #341
      if gettoken ( source ) ~= open then		-- #342
         emiterror ( format ( "expected '%s' but got '%s'" , open , source . token ) , source )		-- #343
         return nil 		-- #344
      end		-- #345
      n = 1 		-- #346
   end		-- #347
   local token = gettoken ( source )		-- #348
   table . insert ( exprstack , savepos ( source ) )		-- #349
   while n >= 1 do		-- #350
      token = eatexpr ( source , token )		-- #351
      if not token then		-- #352
         return nil 		-- #353
      end		-- #354
      if token == open then		-- #355
         n = n + 1 		-- #356
      else		-- #357
         if token == close then		-- #358
            n = n - 1 		-- #359
         end		-- #360
      end		-- #361
      if n >= 1 then		-- #362
         if token ~= ";" then		-- #363
            if nospace [ token ] then		-- #364
               out ( token )		-- #365
            else		-- #366
               out ( token .. " " )		-- #367
            end		-- #368
         end		-- #369
         token = gettoken ( source )		-- #370
      end		-- #371
   end		-- #372
   table . remove ( exprstack )		-- #373
   return token 		-- #374
end		-- #375
		-- #376
local expression_terminators = { [ ";" ] = 1 , }		-- #377
local openclose = { [ "(" ] = ")" , [ "[" ] = "]" , [ "{" ] = "}" , }		-- #378
function processexpression(source , token )		-- #379
   table . insert ( exprstack , savepos ( source ) )		-- #380
   while token do		-- #381
      token = eatexpr ( source , token )		-- #382
      if not token or expression_terminators [ token ] then		-- #383
         break 		-- #384
      end		-- #385
      if nospace [ token ] then		-- #386
         out ( token )		-- #387
      else		-- #388
         out ( token .. " " )		-- #389
      end		-- #390
      local close = openclose [ token ]		-- #391
      if close then		-- #392
         processblock ( source , token , close , 1 )		-- #393
         out ( close )		-- #394
      end		-- #395
      token = gettoken ( source )		-- #396
   end		-- #397
   table . remove ( exprstack )		-- #398
   return token 		-- #399
end		-- #400
		-- #401
function process_if(source , token , what )		-- #402
   if token ~= "(" then		-- #403
      emiterror ( "'(' expected" , source )		-- #404
      return token 		-- #405
   end		-- #406
   outi ( )		-- #407
   out ( what .. " " )		-- #408
   token = processblock ( source , "(" , ")" , 1 )		-- #409
   if what == "if" then		-- #410
      out ( "then" )		-- #411
   else		-- #412
      out ( "do" )		-- #413
   end		-- #414
   outnl ( )		-- #415
   outindent ( 1 )		-- #416
   token = processstatement ( source , gettoken ( source ) , 1 )		-- #417
   outindent ( - 1 )		-- #418
   while what == "if" and token == "elseif" do		-- #419
      token = gettoken ( source )		-- #420
      if token ~= "(" then		-- #421
         emiterror ( "'(' expected" , source )		-- #422
         return token 		-- #423
      end		-- #424
      outi ( )		-- #425
      out ( "elseif " )		-- #426
      token = processblock ( source , "(" , ")" , 1 )		-- #427
      out ( "then" )		-- #428
      outnl ( )		-- #429
      outindent ( 1 )		-- #430
      token = processstatement ( source , gettoken ( source ) , 1 )		-- #431
      outindent ( - 1 )		-- #432
   end		-- #433
   if what == "if" and token == "else" then		-- #434
      outi ( )		-- #435
      out ( token )		-- #436
      outnl ( )		-- #437
      outindent ( 1 )		-- #438
      token = processstatement ( source , gettoken ( source ) , 1 )		-- #439
      outindent ( - 1 )		-- #440
   end		-- #441
   outi ( )		-- #442
   out ( "end" )		-- #443
   outnl ( )		-- #444
   return token 		-- #445
end		-- #446
		-- #447
local keywords = { [ "if" ] = process_if , [ "while" ] = process_if , [ "for" ] = process_if , }		-- #448
function processstatement(source , token , delimited )		-- #449
   if keywords [ token ] then		-- #450
      return keywords [ token ]( source , gettoken ( source ) , token )		-- #451
   else		-- #452
      if token == "{" then		-- #453
         if not delimited then		-- #454
            outi ( )		-- #455
            out ( "do" )		-- #456
            outnl ( )		-- #457
            outindent ( 1 )		-- #458
         end		-- #459
         token = gettoken ( source )		-- #460
         while token and token ~= "}" do		-- #461
            token = processstatement ( source , token )		-- #462
         end		-- #463
         if not delimited then		-- #464
            outindent ( - 1 )		-- #465
            outi ( )		-- #466
            out ( "end" )		-- #467
            outnl ( )		-- #468
         end		-- #469
         token = gettoken ( source )		-- #470
      else		-- #471
         outi ( )		-- #472
         token = processexpression ( source , token )		-- #473
         outnl ( )		-- #474
         if token and token ~= ";" and token ~= "}" then		-- #475
            emiterror ( "warning ';' or '}' expected" , source )		-- #476
            token = gettoken ( source )		-- #477
         end		-- #478
         if token == ";" then		-- #479
            token = gettoken ( source )		-- #480
         end		-- #481
      end		-- #482
   end		-- #483
   return token 		-- #484
end		-- #485
		-- #486
function processsource(source )		-- #487
   local token = gettoken ( source )		-- #488
   while token do		-- #489
      token = processstatement ( source , token )		-- #490
   end		-- #491
end		-- #492
		-- #493
function loadmodule(name , ns )		-- #494
   local mname = "mod_" .. name 		-- #495
   local ons = getfenv ( )		-- #496
   if ns then		-- #497
      setfenv ( 1 , ns )		-- #498
   end		-- #499
   enter_namespace ( mname )		-- #500
   local table = getfenv ( )		-- #501
   local module , error = loadfile ( name .. ".lua" )		-- #502
   if module then		-- #503
      message ( format ( "Module '%s' loaded" , name ) )		-- #504
      setfenv ( module , table )		-- #505
      module ( )		-- #506
      add_options ( table . options )		-- #507
   else		-- #508
      emiterror ( format ( "Could not load module '%s'" , name ) )		-- #509
      message ( error )		-- #510
      table = nil 		-- #511
   end		-- #512
   exit_namespace ( )		-- #513
   setfenv ( 1 , ons )		-- #514
   return table 		-- #515
end		-- #516
		-- #517
function jslua(f )		-- #518
   hasError = nil 		-- #519
   numError = 0 		-- #520
   resultString = { }		-- #521
   local filename = f 		-- #522
   if not f then		-- #523
      filename = "stdin" 		-- #524
   end		-- #525
   message ( "Reading " .. filename )		-- #526
   local source = opensource ( f , filename )		-- #527
   if not source then		-- #528
      return "" 		-- #529
   end		-- #530
   message ( format ( "%d lines, %d tokens" , source . nline , source . ntoken ) )		-- #531
   message ( "Processing " .. filename )		-- #532
   processsource ( source )		-- #533
   closesource ( source )		-- #534
   if hasError then		-- #535
      message ( format ( "%d error(s) while compiling" , numError ) )		-- #536
      return "" 		-- #537
   else		-- #538
      message ( format ( "no error while compiling" ) )		-- #539
   end		-- #540
   return colapse ( resultString )		-- #541
end		-- #542
		-- #543
function dofile(file )		-- #544
   local source = jslua ( file )		-- #545
   local module , error = loadstring ( source )		-- #546
   if module then		-- #547
      module ( )		-- #548
   else		-- #549
      emiterror ( format ( "Could not load string" ) )		-- #550
      message ( error )		-- #551
   end		-- #552
end		-- #553
		-- #554
postprocess = { }		-- #555
function do_postprocess()		-- #556
   local _ , v 		-- #557
   for _ , v in pairs ( postprocess ) do		-- #558
      v ( )		-- #559
   end		-- #560
end		-- #561
		-- #562
function add_postprocess(f )		-- #563
   table . insert ( postprocess , f )		-- #564
end		-- #565
		-- #566
outcurindent = "" 		-- #567
outindentstring = "   " 		-- #568
outindentlevel = 0 		-- #569
function out(s )		-- #570
   table . insert ( resultString , s )		-- #571
end		-- #572
		-- #573
function outf(... )		-- #574
   local s = format ( ... )		-- #575
   out ( s )		-- #576
end		-- #577
		-- #578
function get_outcurindent()		-- #579
   return outcurindent 		-- #580
end		-- #581
		-- #582
function outi()		-- #583
   out ( outcurindent )		-- #584
end		-- #585
		-- #586
local line = 1 		-- #587
function outnl()		-- #588
   line = line + 1 		-- #590
   out ( "\n" )		-- #591
end		-- #592
		-- #593
function outindent(l )		-- #594
   outindentlevel = outindentlevel + l 		-- #595
   outcurindent = string . rep ( outindentstring , outindentlevel )		-- #596
end		-- #597
		-- #598
function option_list(opt )		-- #599
   local i , v 		-- #600
   for i , v in pairs ( opt ) do		-- #601
      emiterror ( i .. " " .. v . help )		-- #602
   end		-- #603
end		-- #604
		-- #605
function option_help()		-- #606
   print ( "usage : jslua [options] [filenames]" )		-- #607
   option_list ( options )		-- #608
   os . exit ( )		-- #609
end		-- #610
		-- #611
function option_module()		-- #612
   local name = option_getarg ( )		-- #613
   loadmodule ( name )		-- #614
end		-- #615
		-- #616
local outhandle = io . stdout 		-- #617
local compileonly 		-- #618
function option_output()		-- #619
   compileonly = 1 		-- #620
   local fn = option_getarg ( )		-- #621
   outhandle = io . open ( fn , "w" )		-- #622
   if not outhandle then		-- #623
      emiterror ( "Failed to open '" .. fn .. "' for writing." )		-- #624
   else		-- #625
      message ( "Opened '" .. fn .. "' for writing ..." )		-- #626
   end		-- #627
end		-- #628
		-- #629
options = { [ "-o" ] = { call = option_output , help = "compile only, and output lua source code to specified file" } , [ "-c" ] = { call = function ()		-- #630
   compileonly = 1 		-- #631
end		-- #632
, help = "compile only, and output lua source code on stdout" } , [ "-v" ] = { call = function ()		-- #633
   verbose = 1 		-- #634
end		-- #635
, help = "turn verbose mode on" } , [ "-d" ] = { call = function ()		-- #636
   dbgmode = 1 		-- #637
end		-- #638
, help = "turn debug mode on" } , [ "--module" ] = { call = option_module , help = "<modulename> load a module" } , [ "--help" ] = { call = option_help , help = "display this help message" } }		-- #639
function add_options(table )		-- #640
   local i , v 		-- #641
   for i , v in pairs ( table ) do		-- #642
      if options [ i ] then		-- #643
         emiterror ( format ( "Option '%s' overriden" , i ) )		-- #644
      end		-- #645
      options [ i ]= v 		-- #646
   end		-- #647
end		-- #648
		-- #649
function option_getarg()		-- #650
   local arg = option_args [ option_argind ]		-- #651
   option_argind = option_argind + 1 		-- #652
   return arg 		-- #653
end		-- #654
		-- #655
exit_namespace ( )		-- #656
if standalone then		-- #657
   local name = arg [ 0 ]		-- #658
   if name then		-- #659
      local i = 0 		-- #660
      local j 		-- #661
      while i ~= nil do		-- #662
         j = i 		-- #663
         i = string . find ( name , "[/\\]" , i + 1 )		-- #664
      end		-- #665
      if j then		-- #666
         name = string . sub ( name , 0 , j )		-- #667
         jslua . message ( format ( "Adding path '%s'" , name ) )		-- #668
         jslua . add_path ( name )		-- #669
      end		-- #670
   end		-- #671
   jslua . option_args = arg 		-- #672
   jslua . option_argind = 1 		-- #673
   local filename = { }		-- #674
   while jslua . option_argind <= #jslua . option_args do		-- #675
      local arg = jslua . option_getarg ( )		-- #676
      if string . sub ( arg , 1 , 1 ) == "-" then		-- #677
         local opt = jslua . options [ arg ]		-- #678
         if opt then		-- #679
            if opt . call then		-- #680
               opt . call ( )		-- #681
            end		-- #682
            if opt . postcall then		-- #683
               jslua . add_postprocess ( opt . postcall )		-- #684
            end		-- #685
         else		-- #686
            jslua . emiterror ( format ( "Unknown option '%s'\n" , arg ) )		-- #687
            jslua . option_help ( )		-- #688
         end		-- #689
      else		-- #690
         table . insert ( filename , arg )		-- #691
      end		-- #692
   end		-- #693
   local function doit(filename )		-- #694
      if compileonly then		-- #695
         local source = jslua . jslua ( filename )		-- #696
         outhandle : write ( source )		-- #697
      else		-- #698
         jslua . dofile ( filename )		-- #699
      end		-- #700
   end		-- #701
		-- #702
   if not next ( filename ) then		-- #703
      doit ( )		-- #704
   else		-- #705
      local _ , v 		-- #706
      for _ , v in pairs ( filename ) do		-- #707
         doit ( v )		-- #708
      end		-- #709
   end		-- #710
   jslua . do_postprocess ( )		-- #711
   if jslua . hasError then		-- #712
      os . exit ( - 1 )		-- #713
   end		-- #714
end		-- #715
