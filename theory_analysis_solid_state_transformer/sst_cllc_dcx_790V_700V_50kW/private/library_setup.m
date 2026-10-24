function varargout = library_setup(url)
%LIBRARY_SETUP  Put pwr-control/library on the MATLAB path, cloning it when it is not on the disk.
%
%   library_setup                    remote https://github.com/pwr-control/library.git
%   library_setup(url)               other remote, e.g. 'git@github.com:pwr-control/library.git' or a fork
%   lib_root = library_setup(...)    root folder of the library clone
%
%   Called at the top of init_model.m, before anything of the library is used. In this order:
%     1. a function of the library is already visible (init_environment): nothing to do;
%     2. the folder named by the environment variable PWR_CONTROL_LIBRARY, when it is set;
%     3. the folder "library" next to this repository (the two repositories cloned side by side, as the README
%        of the repository asks);
%     4. the folder of 2 or 3 does not exist: "git clone <url>" into it (git on the system path), then as 2/3.
%   The folder found or cloned is added to the path with its subfolders (addpath(genpath(...)), which skips
%   .git, private and package folders) for this MATLAB session only: run savepath to keep it.
%   Being in ./private it is seen only by the files of this folder; copy it into the private folder of another
%   project of the repository to use it there (it finds the repository root from its own position).

    if nargin < 1 || isempty(url)
        url = 'https://github.com/pwr-control/library.git';
    end
    probe = 'init_environment';                             % any function of the library

    % repository root from the position of this file: <repo>/theory_analysis_solid_state_transformer/<project>/private
    here      = fileparts(mfilename('fullpath'));
    repo_root = fileparts(fileparts(fileparts(here)));
    lib_root  = getenv('PWR_CONTROL_LIBRARY');
    if isempty(lib_root)
        lib_root = fullfile(fileparts(repo_root), 'library');
    end

    if exist(probe, 'file') == 2
        % <lib_root>/library/setup_files/simulink_models_initialization/init_environment.m
        lib_root = fileparts(fileparts(fileparts(fileparts(which(probe)))));
        fprintf('library_setup: library already on the path (%s)\n', lib_root);
    else
        if ~isfolder(lib_root)
            fprintf('library_setup: library not found, cloning %s into %s ...\n', url, lib_root);
            [st, out] = system(sprintf('git clone "%s" "%s"', url, lib_root));
            if st ~= 0
                error('library_setup:clone', ['git clone failed (status %d):\n%s\nClone the library by hand next ' ...
                    'to this repository (%s), or set the environment variable PWR_CONTROL_LIBRARY to an existing ' ...
                    'copy, then run init_model again.'], st, out, lib_root);
            end
        end
        addpath(genpath(lib_root));
        if exist(probe, 'file') ~= 2
            error('library_setup:notfound', ['%s is on the path but %s.m is not visible: is it a clone of ' ...
                'https://github.com/pwr-control/library?'], lib_root, probe);
        end
        fprintf('library_setup: %s added to the path with its subfolders (this session only, savepath to keep it)\n', ...
            lib_root);
    end

    if nargout > 0
        varargout{1} = lib_root;
    end
end
