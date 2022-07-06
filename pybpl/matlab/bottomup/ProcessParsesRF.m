classdef ProcessParsesRF < BetterHandle
    % ProcessParses : Take a set of random walks, remove duplicate
    %   structure, and parse all of the unique strokes.
    %
    properties (SetAccess = private)
        S_walks = []
        S_indx = []
        I % image
        lib
        verbose
        list_stks
        frozen = false % if true, we cannot add any more parses
    end
    
    properties (Dependent)
        nwalks
        nl
    end
    
    methods
        
        %
        % Input
        %  S_walks: [n x 1 cell] list of random walks
        %
        function this = ProcessParsesRF(I,lib,verbose)
            if ~exist('verbose','var')
               verbose = false; 
            end
            this.verbose = verbose;
            this.I = I;
            this.lib = lib;       
        end
        
        % Add a new parse to the list
        %
        % Input
        %  S_new: [n x 1 cell] list of parses (cell arrays) or
        %           [ns x 1 cell] a single parse
        function add(this,S_new)
           
            if this.frozen
               error('cannot add parse to a frozen class'); 
            end
            
            isvec = iscell(S_new{1});
            if isvec
                nn = numel(S_new);
                for i=1:nn
                   this.add_single_parse(S_new{i}); 
                end
            else
                this.add_single_parse(S_new); 
            end            
        end
        
        % Freeze class such that we cannot add any new strokes 
        function freeze(this)
            
           this.frozen = true;
           
           % Map each of the strokes into its index in the hash table
           for i=1:this.nwalks
                ns = numel(this.S_walks{i});
                this.S_indx{i} = zeros(ns,1);
                for j=1:ns
                    stk = this.S_walks{i}{j};
                    this.S_indx{i}(j) = this.map_stk_to_indx(stk);
                end
           end
           
           % Finish the processing
           %this.smooth;
           this.convert_space;
        end
        
        % Return the list of random walks, now potentially
        % processed
        function S = get_S(this)
           S = cell(this.nwalks,1);
           for i=1:this.nwalks
              myind = this.S_indx{i};
              S{i} = this.list_stks(myind);
              S{i} = S{i}(:);
           end            
        end
        
        % get the number of random walks
        function y = get.nwalks(this)
           y = numel(this.S_walks); 
        end        
        
        % get the number of strokes in the list
        function y = get.nl(this)
           y = numel(this.list_stks); 
        end
        
        % Smooth each of the strokes with a spline
        function smooth(this)
            this.list_stks = smooth_walk(this.list_stks,this.I);                     
        end
        
        % Convert image to motor space
        function convert_space(this)
            nl = this.nl;
            mylist = this.list_stks;
            for i=1:nl
                mylist{i} = space_img_to_motor(mylist{i});
            end          
            this.list_stks = mylist;
        end
               
    end
    
    methods (Access = private)
       
        % Add a singlenew parse to the list
        function add_single_parse(this,parse_new)
            
            % put in canonical format
            parse_new = walk_to_canonical(parse_new); 
            
            % if this walk is a duplicate, do nothing
            for i=1:this.nwalks
                if isequal_walk(parse_new,this.S_walks{i})
                    return;
                end
            end
            this.S_walks = [this.S_walks; {parse_new}];
            
            % add any new strokes to the list of strokes
            new_stks = flatten_nested(parse_new);
            ns = numel(new_stks);
            for sid=1:ns
               this.add_stroke(new_stks{sid}); 
            end            
            
        end
        
        % Try to add a stroke to the list. If it already exists,
        % do nothing
        %
        % Input
        %  new_stk: [n x 2] trajectory
        %
        function add_stroke(this,new_stk)
            for i=1:this.nl
               if isequal(new_stk,this.list_stks{i})
                  return 
               end
            end
            this.list_stks = [this.list_stks; {new_stk}];
        end
        
        % For a given stroke "stk", which index does it match too
        % in our library?
        function indx = map_stk_to_indx(this,stk)            
            n = numel(this.list_stks);
            for i=1:n
                if isequal(stk,this.list_stks{i})
                    indx = i;
                    return
                end
            end
            error('stroke not found');
        end
        
        
    end
    
end