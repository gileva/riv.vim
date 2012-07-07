"=============================================
"    Name: restin/insert.vim
"    File: restin/insert.vim
"  Author: Rykka G.Forest
"  Update: 2012-07-07
"=============================================
let s:cpo_save = &cpo
set cpo-=C

let s:p = g:_riv_p
let s:list_or_nonspace = s:p.all_list.'|^\S'

let s:f_cols = []
let s:f_row = 0
let s:f_buf = 0

" for new line's indent
fun! riv#insert#indent(row) "{{{
    let pnb_num = prevnonblank(a:row - 1)
    if pnb_num == 0
        return 0
    endif

    let p_line = getline(a:row - 1)

    let pnb_line = getline(pnb_num)
    let ind = indent(pnb_num)
    
    " list
    " 1~2:start of list content
    " 3:  indent of list  
    " 4:  start of prev list left edge.
    let l_ind = matchend(pnb_line, s:p.all_list)
    if l_ind != -1 &&  a:row <= pnb_num+2 
        return (ind + l_ind - matchend(pnb_line, '^\s*'))
    elseif l_ind != -1 &&  a:row <= pnb_num+3 
        return ind
    elseif l_ind != -1 &&  a:row >= pnb_num+4 
        call cursor(pnb_num,1)
        let p_lnum = searchpos(s:list_or_nonspace, 'bW')[0]
        let p_ind  = matchend(getline(p_lnum),s:p.all_list)
        if p_ind != -1
            return indent(p_lnum)
        endif
    endif
    
    " literal-block
    " 1~2+:ind  
    " 2:
    let l_ind = matchend(pnb_line, s:p.literal_block)
    if l_ind != -1 &&  a:row == pnb_num+2
        return ind
    endif

    " exp_markup
    " 1~2: ind
    let l_ind = matchend(pnb_line, s:p.exp_mark)
    if l_ind != -1 &&  a:row <= pnb_num+2
        return l_ind
    endif
    
    " one empty without match
    " 1~2: ind
    " 3 : check prev exp_mark or list
    " 4+ : 0
    if a:row > pnb_num+3
        return 0
    elseif  a:row > pnb_num+2
        call cursor(pnb_num,1)
        let p_row = searchpos(s:p.all_list.'|^\s*\.\.\s\|^\S', 'bW')[0]
        let p_line = getline(p_row)
        let p_ind  = matchend(p_line,'^\s*\.\.\s')
        if p_ind != -1
            return p_ind
        endif
        let p_ind  = matchend(p_line, s:p.all_list)
        if p_ind != -1
            return indent(p_row)
        endif
    endif

    return ind
endfun "}}}

" indent for the same line action
fun! riv#insert#fix_indent(row) "{{{
    
    let pnb_num = prevnonblank(a:row - 1)
    if pnb_num == 0
        return 0
    endif

    let p_line = getline(a:row - 1)

    " Field List
    " 1:ind
    let p_ind =  matchend(p_line, g:_riv_p.field_list_full)
    if p_ind != -1
        return p_ind
    endif

    let pnb_line = getline(pnb_num)
    let ind = indent(pnb_num)
    
    " list
    " <=3: ind: we want a stop at the list begin here
    let l_ind = matchend(pnb_line, g:_riv_p.all_list)
    if l_ind != -1
        return ind
    endif
    
    " literal-block
    " 1/2+:ind  
    " 2:4
    let l_ind = matchend(pnb_line, g:_riv_p.literal_block)
    if l_ind != -1 &&  a:row == pnb_num+2
        return 4
    endif

    " exp_markup
    " 1~2: ind
    let l_ind = matchend(pnb_line, g:_riv_p.exp_mark)
    if l_ind != -1 &&  a:row <= pnb_num+2
        return (ind + l_ind - matchend(pnb_line, g:_riv_p.indent))
    endif
    
    " without match
    " 1+: search list/exp_mark or  \S starting line to stop.
    if a:row >= pnb_num+1
        call cursor(pnb_num,1)
        let p_num = searchpos(g:_riv_p.indent_stoper, 'bW')[0]
        let p_line = getline(p_num)
        let l_ind  = matchend(p_line,'^\s*\.\.\s')
        if l_ind != -1
            return l_ind
        endif
        let l_ind = matchend(p_line, g:_riv_p.all_list)
        if l_ind != -1
            return indent(p_num)
        endif
    endif
    
    return ind
endfun "}}}

" indent for the same line action advanced.
fun! riv#insert#fixed_col(row,col,sft) "{{{
    " return with fix indentation with row col and direction
    " context is the item with smaller indentation (parent)
    " find all possible context of current row
    if s:f_row == a:row && s:f_buf == bufnr('%')
        return riv#ptn#fix_sfts(a:col, s:f_cols, a:sft)
    endif
    let pnb_row = prevnonblank(a:row - 1)
    if pnb_row == 0
        return a:col + a:sft
    endif
    let f_idts = [indent(pnb_row)+1]

    let blk_row = riv#ptn#get(g:_riv_p.literal_block, a:row)
    if blk_row
        let f_idts += [indent(blk_row)+1+&sw]
    endif
    let lst_row = riv#list#get_all_list(a:row)
    if lst_row 
        let lst_idt = indent(lst_row)+1
        let lst_cdt  =riv#list#get_con_idt(getline(lst_row))
        let f_idts += [lst_idt,lst_cdt]
        let par_row = riv#list#get_parent(lst_row)
        if par_row
            let par_idt = indent(par_row)+1
            let par_cdt  =riv#list#get_con_idt(getline(par_row))
            let f_idts += [par_idt, par_cdt]
        endif
    else
        let exp_row = riv#ptn#get(g:_riv_p.exp_mark, a:row)
        let exp_cdt = riv#ptn#exp_con_idt(getline(exp_row))
        let f_idts += [exp_cdt]
    endif

    let s:f_cols = f_idts
    let s:f_row = a:row
    let s:f_buf = bufnr('%')
    return riv#ptn#fix_sfts(a:col,f_idts,a:sft)
    
endfun "}}}
fun! riv#insert#fixed_sft(row,col,sft) "{{{
    return riv#insert#fixed_col(a:row,a:col,a:sft) - a:col
endfun "}}}
fun! riv#insert#get_fidt() "{{{
    return riv#insert#fixed_col(line('.'),col('.'),&sw)
endfun "}}}

fun! riv#insert#shiftleft() "{{{
    let sft =  -&sw
    let [row,col]  = getpos('.')[1:2]
    let line = getline('.')
    if line[:col-2] =~ '^\s*$'
        let fix_sft = riv#insert#fixed_sft(row,col,sft)
        if fix_sft != sft && fix_sft!=0
            return repeat("\<Left>\<Del>", abs(fix_sft))
        endif
    endif
    return "\<BS>"
endfun "}}}
                                            
fun! riv#insert#shiftright() "{{{
    let sft =  &sw
    let [row,col]  = getpos('.')[1:2]
    let line = getline('.')
    if line[:col-2] =~ '^\s*$'
        let fix_sft = riv#insert#fixed_sft(row,col,sft)
        if fix_sft != sft && fix_sft!=0
            return repeat("\<Space>", abs(fix_sft))
        endif
    endif
    return "\<Tab>"
endfun "}}}
if expand('<sfile>:p') == expand('%:p') 

endif
let &cpo = s:cpo_save
unlet s:cpo_save
