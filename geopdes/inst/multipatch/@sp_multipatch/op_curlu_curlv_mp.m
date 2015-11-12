function A = op_curlu_curlv_mp (spu, spv, msh, coeff, patch_list)

  if (nargin < 5)
    patch_list = 1:msh.npatch;
  end

  if ((spu.npatch ~= spv.npatch) || (spu.npatch ~= msh.npatch))
    error ('op_curlu_curlv_mp: the number of patches does not coincide')
  end
  
  ncounter = 0;
  for iptc = patch_list
    [rs, cs, vs] = op_curlu_curlv_tp (spu.sp_patch{iptc}, spv.sp_patch{iptc}, msh.msh_patch{iptc}, coeff);
    rows(ncounter+(1:numel (rs))) = spv.gnum{iptc}(rs);
    cols(ncounter+(1:numel (rs))) = spu.gnum{iptc}(cs);

    if (~isempty (spv.dofs_ornt))
      vs = spv.dofs_ornt{iptc}(rs)' .* vs;
    end
    if (~isempty (spu.dofs_ornt))
      vs = vs .* spu.dofs_ornt{iptc}(cs)';
    end
    
    vals(ncounter+(1:numel (rs))) = vs;
    ncounter = ncounter + numel (rs);
  end

  A = sparse (rows, cols, vals, spv.ndof, spu.ndof);
  clear rows cols vals rs cs vs

end