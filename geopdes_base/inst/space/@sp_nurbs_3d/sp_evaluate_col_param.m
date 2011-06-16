% SP_EVALUATE_COL_PARAM: compute the basis functions, in the parametric domain, in one column of the mesh.
%
%     sp = sp_evaluate_col_param (space, msh, colnum, 'option1', value1, ...)
%
% INPUTS:
%     
%     space:  class defining the space of discrete functions (see sp_nurbs_3d)
%     msh:    msh structure containing (in the field msh.qn) the points 
%              along each parametric direction in the parametric 
%              domain at which to evaluate, i.e. quadrature points 
%              or points for visualization (see msh_3d/msh_evaluate_col)
%     colnum: number of the fixed element in the first parametric direction
%    'option', value: additional optional parameters, currently available options are:
%            
%              Name     |   Default value |  Meaning
%           ------------+-----------------+----------------------------------
%            value      |      true       |  compute shape_functions
%            gradient   |      true       |  compute shape_function_gradients
%
% OUTPUT:
%
%    sp: struct representing the discrete function space, with the following fields:
%
%    FIELD_NAME      (SIZE)                      DESCRIPTION
%    ncomp           (scalar)                          number of components of the functions of the space (actually, 1)
%    ndof            (scalar)                          total number of degrees of freedom
%    ndof_dir        (1 x 3 vector)                    degrees of freedom along each direction
%    nsh_max         (scalar)                          maximum number of shape functions per element
%    nsh             (1 x msh.nelcol vector)           actual number of shape functions per each element
%    connectivity    (nsh_max x msh.nelcol vector)     indices of basis functions that do not vanish in each element
%    shape_functions (msh.nqn x nsh_max x msh.nelcol)  basis functions evaluated at each quadrature node in each element
%    shape_function_gradients
%                 (3 x msh.nqn x nsh_max x msh.nelcol) basis function gradients evaluated at each quadrature node in each element
%
% Copyright (C) 2009, 2010, 2011 Carlo de Falco
% Copyright (C) 2011 Rafael Vazquez
%
%    This program is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.

%    This program is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with this program.  If not, see <http://www.gnu.org/licenses/>.

function [sp, elem_list] = sp_evaluate_col_param (space, msh, colnum, varargin)

value = true;
gradient = true;
if (~isempty (varargin))
  if (~rem (length (varargin), 2) == 0)
    error ('sp_evaluate_col_param: options must be passed in the [option, value] format');
  end
  for ii=1:2:length(varargin)-1
    if (strcmpi (varargin {ii}, 'value'))
      value = varargin {ii+1};
    elseif (strcmpi (varargin {ii}, 'gradient'))
      gradient = varargin {ii+1};
    else
      error ('sp_evaluate_col_param: unknown option %s', varargin {ii});
    end
  end
end

nel_col = msh.nelv * msh.nelw;
indu = colnum * ones(msh.nelv, msh.nelw);
indv = repmat ((1:msh.nelv)', 1, msh.nelw);
indw = repmat ((1:msh.nelw), msh.nelv, 1);

elem_list = sub2ind ([msh.nelu, msh.nelv, msh.nelw], indu, indv, indw);
elem_list = elem_list(:);

spu = space.spu;
spv = space.spv;
spw = space.spw;

nsh  = spu.nsh(colnum) * spv.nsh' * spw.nsh;
nsh  = nsh(:)';
ndof = spu.ndof * spv.ndof * spw.ndof;
ndof_dir = [spu.ndof, spv.ndof, spw.ndof];

connectivity = space.connectivity(:,elem_list);

shp_u = reshape (spu.shape_functions(:, :, colnum), ...
                 msh.nqnu, 1, 1, spu.nsh_max, 1, 1, 1, 1);  %% one column only
shp_u = repmat  (shp_u, [1, msh.nqnv, msh.nqnw, 1, spv.nsh_max, spw.nsh_max, msh.nelv, msh.nelw]);
shp_u = reshape (shp_u, msh.nqn, space.nsh_max, nel_col);

shp_v = reshape (spv.shape_functions, 1, msh.nqnv, 1, 1, spv.nsh_max, 1, msh.nelv, 1);
shp_v = repmat  (shp_v, [msh.nqnu, 1, msh.nqnw, spu.nsh_max, 1, spw.nsh_max, 1, msh.nelw]);
shp_v = reshape (shp_v, msh.nqn, space.nsh_max, nel_col);

shp_w = reshape (spw.shape_functions, 1, 1, msh.nqnw, 1, 1, spw.nsh_max, 1, msh.nelw);
shp_w = repmat (shp_w, [msh.nqnu, msh.nqnv, 1, spu.nsh_max, spv.nsh_max, 1, msh.nelv, 1]);
shp_w = reshape (shp_w, msh.nqn, space.nsh_max, nel_col);

% Multiply each function by the weight and compute the denominator
W = space.weights (connectivity);
W = repmat (reshape (W, 1, space.nsh_max, nel_col), [msh.nqn, 1, 1]);
shape_functions = W.* shp_u .* shp_v .* shp_w;
D = repmat (reshape (sum (shape_functions, 2), msh.nqn, 1, nel_col), [1, space.nsh_max, 1]);
shape_functions = shape_functions ./ D;

sp = struct('nsh_max', space.nsh_max, 'nsh', nsh, 'ndof', ndof,  ...
            'ndof_dir', ndof_dir, 'connectivity', connectivity, ...
            'ncomp', 1);
if (value)
  sp.shape_functions = shape_functions;
end

if (gradient)
  shg_u = reshape (spu.shape_function_gradients(:, :, colnum), ...
                 msh.nqnu, 1, 1, spu.nsh_max, 1, 1, 1, 1);  %% one column only
  shg_u = repmat  (shg_u, [1, msh.nqnv, msh.nqnw, 1, spv.nsh_max, spw.nsh_max, msh.nelv, msh.nelw]);
  shg_u = reshape (shg_u, msh.nqn, space.nsh_max, nel_col);

  shg_v = reshape (spv.shape_function_gradients, ...
            1, msh.nqnv, 1, 1, spv.nsh_max, 1, msh.nelv, 1);
  shg_v = repmat (shg_v, [msh.nqnu, 1, msh.nqnw, spu.nsh_max, 1, spw.nsh_max, 1, msh.nelw]);
  shg_v = reshape (shg_v, msh.nqn, space.nsh_max, nel_col);

  shg_w = reshape (spw.shape_function_gradients, ...
            1, 1, msh.nqnw, 1, 1, spw.nsh_max, 1, msh.nelw);
  shg_w = repmat (shg_w, [msh.nqnu, msh.nqnv, 1, spu.nsh_max, spv.nsh_max, 1, msh.nelv, 1]);
  shg_w = reshape (shg_w, msh.nqn, space.nsh_max, nel_col);

  Bu = W .* shg_u .* shp_v .* shp_w ;
  Bv = W .* shp_u .* shg_v .* shp_w ;
  Bw = W .* shp_u .* shp_v .* shg_w ;

  Du = repmat (reshape (sum (Bu, 2), msh.nqn, 1, nel_col), [1, sp.nsh_max, 1]);
  Dv = repmat (reshape (sum (Bv, 2), msh.nqn, 1, nel_col), [1, sp.nsh_max, 1]);
  Dw = repmat (reshape (sum (Bw, 2), msh.nqn, 1, nel_col), [1, sp.nsh_max, 1]);

  sp.shape_function_gradients(1,:,:,:) = (Bu - shape_functions .* Du)./D;
  sp.shape_function_gradients(2,:,:,:) = (Bv - shape_functions .* Dv)./D;
  sp.shape_function_gradients(3,:,:,:) = (Bw - shape_functions .* Dw)./D;

  clear  shg_u shg_v shg_w Bu Bv Bw Du Dv Dw
end

clear shp_u shp_v shp_w

end