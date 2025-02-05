%% ERPs analysis script - Estelle Herv� - 2022 - %80PRIME Project

%% Variables to enter manually before running the code

% Load EEGLAB 
% addpath(genpath('/Users/anne-sophiedubarry/Documents/4_Software/eeglab2020_0'));
tmp = pwd ; 
cd '/Users/anne-sophiedubarry/Documents/4_Software/eeglab2020_0' ; 
% Open eeglab
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;
run('/Users/anne-sophiedubarry/Documents/0_projects/in_progress/ABRBABY_cfrancois/dev/signal_processing/biosig4octmat-3.8.0/biosig_installer.m') ; 

cd(tmp) ; 

% Set filepath (must contain .bdf and .txt files from recording)
% INDIR = '/Users/anne-sophiedubarry/Documents/0_projects/in_progress/ABRBABY_cfrancois/data';
INDIR = '/Users/anne-sophiedubarry/Documents/0_projects/in_progress/ABRBABY_cfrancois/data/DEVLANG_data' ;

% Reads all folders that are in INDIR 
d = dir(INDIR); 
isub = [d(:).isdir]; % returns logical vector if is folder
subjects = {d(isub).name}';
subjects(ismember(subjects,{'.','..'})) = []; % Removes . and ..

% Set variables for filtering
% hp = 0.1; %value for high-pass filter (Hz) (APICE)
% lp = 40; %value for low-pass filter (Hz) (APICE) 
hp = 1; %value for high-pass filter (Hz) (APICE)
lp = 30; %value for low-pass filter (Hz) (APICE) 


% Rejection treshold for bad epochs
rej_low = -150; %150 infants; 120 adults
rej_high = 150; %150 infants; 120 adults

% List of channel labels to reref with 
mastos = {'Lmon','Rmon','MASTOG','MASTOD'};
trig = {'Erg1'};

baseline = [-99, 0] ; 
win_of_interest = [-0.1, 0.5] ; 
conditions = {'STD','DEV1','DEV2'} ; 
elec = 1:16 ; 

% FOR SANITY CHECK
for jj=find(ismember(subjects,'DVL_007_T8'))

% Loop through subjects
% for jj=1:length(subjects) 
        
%     fprintf(strcat(subjects{jj}, '...\n'));
%     jj=find(ismember(subjects,'DVL_007_T8')) ; 
    
    %% IMPORT
    % Get BDF file
    fname= dir(fullfile(INDIR,subjects{jj},'*.bdf'));
 
    % Select bdf file in the folder
    EEG = pop_biosig(fullfile(INDIR, subjects{jj}, fname.name));

    % Find REF electrodes indices by labels 
    ref_elec = find(ismember({EEG.chanlocs.labels},mastos)); 
    
    % Save a first dataset in EEGLAB 
    [~,filename,~] = fileparts(fname.name);    
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 1,'setname',filename,'gui','off');
 
    %% RE-REF (excluding trig channel)
    % Find TRIG electrodes indices by labels 
    trigg_elec = find(ismember({EEG.chanlocs.labels},trig)); 

    % Re-reference data and rename new file
    EEG = pop_reref(EEG, ref_elec, 'exclude',trigg_elec, 'keepref','on');
    
    %% EVENTS 
    % Extract event from trigger channel (Erg1)
    EEG = pop_chanevent(EEG, trigg_elec,'oper','X>20000','edge','leading','edgelen',1);
    
    % Identifies outliers events (e.g. boundaries) or too close events 
    idx_to_remove = [   find(diff([EEG.event.latency])<0.1*EEG.srate)+1,... % minimum intretrial duration = 220 ms
                        find(diff([EEG.event.latency])>2*EEG.srate) ];        
    
    % Removes outliers events
    EEG.event(idx_to_remove) = [] ;  EEG.urevent(idx_to_remove) = [] ; 
    
    % Relabels events with condition name (defined in txt file <SUBJECT>.txt)
    EEG.event = read_custom_events(strrep(fullfile(fname.folder,fname.name),'.bdf','.txt'),EEG.event) ;
    EEG.orig_events = EEG.urevent ; EEG.urevent = EEG.event;
    
    %% FILTERS the data with ERPLab
%     EEG  = pop_basicfilter(EEG,  elec , 'Boundary', 'boundary', 'Cutoff', [hp lp], 'Design', 'butter', 'Filter', 'bandpass', 'Order',  2, 'RemoveDC', 'on' );
    [ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
    EEG = eeg_checkset( EEG );

    %% SAVE DATASET BEFORE EPOCHING
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET, 'setname', strcat(filename,'_filtered'),'savenew', fullfile(INDIR,subjects{jj}, strcat(filename,'_filtered')),'gui','off');
    CURR_FILTERED = CURRENTSET ; 
    
    % Extract ALL conditions epochs
%     EEG = pop_epoch(EEG, {conditions{cc}}, win_of_interest, 'newname', strcat(filename,'_',conditions{cc}), 'epochinfo', 'yes');
    EEG = pop_epoch(EEG, conditions, win_of_interest, 'newname', strcat(filename,'_ALL'), 'epochinfo', 'yes');

    % Remove baseline
    EEG = pop_rmbase( EEG, baseline,[] );
    
    % Add channels information
    EEG=pop_chanedit(EEG, 'lookup','/Users/anne-sophiedubarry/Documents/4_Software/eeglab2020_0/plugins/dipfit/standard_BEM/elec/standard_1005.elc');

    % Select DEV
    [EEG_DEV1,target_indices1] = pop_selectevent(EEG,'type','DEV1');
    [EEG_DEV2,target_indices2] = pop_selectevent(EEG,'type','DEV2');
    [EEG_STD,target_indices_std] = pop_selectevent(EEG,'type','STD');
    
    idx_std1 = target_indices_std(ismember(target_indices_std,target_indices1-1));
    idx_std2 = target_indices_std(ismember(target_indices_std,target_indices2-1));
    
    [EEG_STD1,target_indices_std1] = pop_selectevent(EEG,'event',idx_std1);
    [EEG_STD2,target_indices_std2] = pop_selectevent(EEG,'event',idx_std2);
   
    [EEG_STD1_thresh,idx_std1_rej] = pop_eegthresh(EEG_STD1,1,elec ,rej_low, rej_high, win_of_interest(1), win_of_interest(2),0,1);
    [EEG_STD2_thresh,idx_std2_rej] = pop_eegthresh(EEG_STD2,1,elec ,rej_low, rej_high, win_of_interest(1), win_of_interest(2),0,1);
    [EEG_DEV1_thresh,idx_dev1_rej] = pop_eegthresh(EEG_DEV1,1,elec ,rej_low, rej_high, win_of_interest(1), win_of_interest(2),0,1);
    [EEG_DEV2_thresh,idx_dev2_rej] = pop_eegthresh(EEG_DEV2,1,elec ,rej_low, rej_high, win_of_interest(1), win_of_interest(2),0,1);
   
    [EEG_STD_thresh, idx_removed] = pop_eegthresh(EEG_STD,1,elec ,rej_low, rej_high, win_of_interest(1), win_of_interest(2),0,1);
   
    std_good = setdiff(1:900,target_indices_std(idx_removed)); 
    begining_of_block = repelem((1:30:900)-1,3)+repmat(1:3,1,30); 
    
     % IF nubmber of STD < number of DEV : randomly select other STD
    if length(EEG_DEV1_thresh.event)>length(EEG_STD1_thresh.event)
        % Number of trial to add in STD
        ntrials =  length(EEG_DEV1_thresh.event)-length(EEG_STD1_thresh.event) ; 
        
        % Pool of STD without those rejected by threshold detection
        pool_std1 = setdiff(std_good,target_indices1);   
        
        % Pool of STD without beginners in block (3 first trials) 
        pool_std1_w_no_beginners = setdiff(pool_std1,begining_of_block);
        
        % Trials which were already selected 
        idx_std1_already_included = setdiff(target_indices_std1, target_indices_std1(idx_std1_rej)) ; 
        
        % Trials to add to balance the number of trial to the same number
        % as DEV
        idx_to_add = pool_std1_w_no_beginners(randperm(length(pool_std1_w_no_beginners),ntrials));
        
        % Select trial : 1) randomly a number = ntrial and 2) those which
        % were already selected and 'good'
        [EEG_STD_ALL,~] = pop_selectevent(EEG,'event',[idx_std_already_included idx_to_add]);
 
    end
  
%     
%     
%     % IF nubmber of STD < number of DEV : randomly select other STD
%     if length(EEG_DEV1_thresh.event)>length(EEG_STD1_thresh.event)
%         ntrials =  length(EEG_DEV1_thresh.event)-length(EEG_STD1_thresh.event) ; 
%         [EEG_STD1_ALL] = balance_number_of_STD(EEG,ntrials,idx_std1,target_indices_std1,idx_std1_rej,target_indices_std1(idx_removed)) ; 
%     end
%     
%     % IF nubmber of STD < number of DEV : randomly select other STD
%     if length(EEG_DEV2_thresh.event)>length(EEG_STD2_thresh.event)
%         ntrials =  length(EEG_DEV2_thresh.event)-length(EEG_STD2_thresh.event) ; 
%         [EEG_STD2_ALL] = balance_number_of_STD(EEG,ntrials,idx_std2,target_indices_std2,idx_std2_rej,target_indices_std2(idx_removed)) ; 
%     end
%  
 
    %% SANITY CHECK DISPLAY F3-FZ-F4 , C3-CZ-C4 ou une topo complete? (16 elec)
%     % ii= 5 corresponds to electrode F3 
grd_STD_F3 = squeeze(mean(STD_subj(:,5,:),1)) ; 
grd_DEV1_F3 = squeeze(mean(DEV1_subj(:,5,:),1)) ; 
grd_DEV2_F3 = squeeze(mean(DEV2_subj(:,5,:),1)) ; 

% figure ; 
% plot(EEG_dev2.times,grd_STD_F3,'k','Linewidth',1.5); hold on ;set(gca,'YDir','reverse') ;
% plot(EEG_dev2.times,grd_DEV1_F3,'r','Linewidth',1.5);  hold on; set(gca,'YDir','reverse') ;
% plot(EEG_dev2.times, grd_DEV2_F3,'b','Linewidth',1.5); set(gca,'YDir','reverse') ;
% grid on ; 
% 
% legend('STD','DEV1','DEV2');
% xlabel('Times (ms)'); ylabel('uV'); title ('Grand average F3');
    
    %%%% TO FINISH (following APICE?)
    
    
    %% GET FFR - 
    
end

%--------------------------------------------------------------
% FUNCTION that select from EEG_STD ntrial with no repetition with exisitng
% STD 
%--------------------------------------------------------------
function [EEG_STD_ALL] = balance_number_of_STD(EEG,ntrials,idx_std,target_indices_std,idx_std_rej,idx_removed) 

       idx_std_after_rej = setdiff(idx_removed, target_indices_std); 
   
       trials_std_not_incl_yet = setdiff(idx_std_after_rej,idx_std) ; 
       idx_to_add = trials_std_not_incl_yet(randperm(length(trials_std_not_incl_yet),ntrials));
       idx_std_already_included = setdiff(target_indices_std, target_indices_std(idx_std_rej)) ; 
       [EEG_STD_ALL,~] = pop_selectevent(EEG,'event',[idx_std_already_included idx_to_add]);
       
end
    
%--------------------------------------------------------------
% FUNCTION that reads events from text file and output 
% an EEGLAB events structure 
%--------------------------------------------------------------
function out_event = read_custom_events(fname, in_event) 

% Read .txt 
my_events = readtable(fname, 'ReadVariableNames', 0);

% Insert info from .txt into EEG.event
my_events = table2array(my_events);

out_event = struct('latency', {in_event(:).latency}, ...
                'type', (my_events(:))',...
                'urevent', {in_event(:).urevent});

end