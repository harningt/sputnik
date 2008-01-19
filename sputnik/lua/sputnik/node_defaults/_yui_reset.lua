module(..., package.seeall)

NODE = {
   title="YUI Foundation Style",
   prototype="@CSS",
}
NODE.content=[=[
/*
Copyright (c) 2007, Yahoo! Inc. All rights reserved.
Code licensed under the BSD License:
http://developer.yahoo.net/yui/license.txt
version: 2.2.2
*/
/*reset.css*/body,div,dl,dt,dd,ul,ol,li,h1,h2,h3,h4,h5,h6,pre,form,fieldset,input,textarea,p,blockquote,th,td{margin:0;padding:0;}table{border-collapse:collapse;border-spacing:0;}fieldset,img{border:0;}address,caption,cite,code,dfn,em,strong,th,var{font-style:normal;font-weight:normal;}ol,ul {list-style:none;}caption,th {text-align:left;}h1,h2,h3,h4,h5,h6{font-size:100%;font-weight:normal;}q:before,q:after{content:'';}abbr,acronym {border:0;}
/*fonts.css*/body{font:13px arial,helvetica,clean,sans-serif;*font-size:small;*font:x-small;}table {font-size:inherit;font:100%;}select, input, textarea {font:99% arial,helvetica,clean,sans-serif;}pre, code {font:115% monospace;*font-size:100%;}body * {line-height:1.22em;}
/*grids.css*/body{text-align:center;}#ft{clear:both;}#doc,#doc2,#doc3,.yui-t1,.yui-t2,.yui-t3,.yui-t4,.yui-t5,.yui-t6,.yui-t7{margin:auto;text-align:left;width:57.69em;*width:56.3em;min-width:750px;}#doc2{width:73.074em;*width:71.313em;min-width:950px;}#doc3{margin:auto 10px;width:auto;}.yui-b{position:relative;}.yui-b{_position:static;}#yui-main .yui-b{position:static;}#yui-main{width:100%;}.yui-t1 #yui-main,.yui-t2 #yui-main,.yui-t3 #yui-main{float:right;margin-left:-25em;}.yui-t4 #yui-main,.yui-t5 #yui-main,.yui-t6 #yui-main{float:left;margin-right:-25em;}.yui-t1 .yui-b{float:left;width:12.3207em;*width:12.0106em;}.yui-t1 #yui-main .yui-b{margin-left:13.3207em;*margin-left:13.0106em;}.yui-t2 .yui-b{float:left;width:13.8456em;*width:13.512em;}.yui-t2 #yui-main .yui-b{margin-left:14.8456em;*margin-left:14.512em;}.yui-t3 .yui-b{float:left;width:23.0759em;*width:22.52em;}.yui-t3 #yui-main .yui-b{margin-left:24.0759em;*margin-left:23.52em;}.yui-t4 .yui-b{float:right;width:13.8456em;*width:13.512em;}.yui-t4 #yui-main .yui-b{margin-right:14.8456em;*margin-right:14.512em;}.yui-t5 .yui-b{float:right;width:18.4608em;*width:18.016em;}.yui-t5 #yui-main .yui-b{margin-right:19.4608em;*margin-right:19.016em;}.yui-t6 .yui-b{float:right;width:23.0759em;*width:22.52em;}.yui-t6 #yui-main .yui-b{margin-right:24.0759em;*margin-right:23.52em;}.yui-t7 #yui-main .yui-b{display:block;margin:0 0 1em 0;}#yui-main .yui-b{float:none;width:auto;}.yui-g .yui-u,.yui-g .yui-g,.yui-gc .yui-u,.yui-gc .yui-g .yui-u,.yui-ge .yui-u,.yui-gf .yui-u{float:right;display:inline;}.yui-g div.first,.yui-gc div.first,.yui-gc div.first div.first,.yui-gd div.first,.yui-ge div.first,.yui-gf div.first{float:left;}.yui-g .yui-u,.yui-g .yui-g{width:49.1%;}.yui-g .yui-g .yui-u,.yui-gc .yui-g .yui-u{width:48.1%;}.yui-gb .yui-u,.yui-gc .yui-u,.yui-gd .yui-u{float:left;margin-left:2%;*margin-left:1.895%;width:32%;}.yui-gb div.first,.yui-gc div.first,.yui-gd div.first{margin-left:0;}.yui-gc div.first,.yui-gd .yui-u{width:66%;}.yui-gd div.first{width:32%;}.yui-ge .yui-u{width:24%;}.yui-ge div.first,.yui-gf .yui-u{width:74.2%;}.yui-gf div.first{width:24%;}.yui-ge div.first{width:74.2%;}#bd:after,.yui-g:after,.yui-gb:after,.yui-gc:after,.yui-gd:after,.yui-ge:after,.yui-gf:after{content:".";display:block;height:0;clear:both;visibility:hidden;}#bd,.yui-g,.yui-gb,.yui-gc,.yui-gd,.yui-ge,.yui-gf{zoom:1;}
]=]
