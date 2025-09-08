% track_seperation_ICA.m
% ICA-based track separation for two audio files

% Select two audio files
[file1, path1] = uigetfile({'*.wav'; '*.mp3'}, 'Select first audio file');
if isequal(file1,0)
    disp('No file selected. Exiting script.');
    return;
end
[file2, path2] = uigetfile({'*.wav'; '*.mp3'}, 'Select second audio file');
if isequal(file2,0)
    disp('No file selected. Exiting script.');
    return;
end
audio1 = audioread(fullfile(path1, file1));
audio2 = audioread(fullfile(path2, file2));

% Convert to mono if stereo
if size(audio1,2) > 1
    audio1 = mean(audio1,2);
end
if size(audio2,2) > 1
    audio2 = mean(audio2,2);
end

% Match lengths
N = min(length(audio1), length(audio2));
audio1 = audio1(1:N);
audio2 = audio2(1:N);

fs = 44100; % Default, will try to get from file info if possible
info1 = audioinfo(fullfile(path1, file1));
info2 = audioinfo(fullfile(path2, file2));
if isfield(info1, 'SampleRate')
    fs = info1.SampleRate;
end

% Combine using two different mixing matrices
mix1 = 0.6*audio1 + 0.8*audio2;
mix2 = 0.8*audio1 + 0.6*audio2;
X = [mix1 mix2]'; % 2 x N

% ICA separation
% Use FastICA if available, else use basic implementation
try
    [icasig, ~, ~] = fastica(X);
catch
    % Basic ICA using eigendecomposition
    X = X - mean(X,2);
    C = cov(X');
    [E, D] = eig(C);
    S = E' * X;
    icasig = S;
end
sep1 = icasig(1,:)';
sep2 = icasig(2,:)';

% Save combined and separated files
output_dir = '../outputs/';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end
audiowrite([output_dir 'ICA_mix1.wav'], mix1, fs);
audiowrite([output_dir 'ICA_mix2.wav'], mix2, fs);
audiowrite([output_dir 'ICA_sep1.wav'], sep1, fs);
audiowrite([output_dir 'ICA_sep2.wav'], sep2, fs);

% Plot important signals (limit to 0.1s in the middle)
segment_time = 0.1;
mid_sample = round(N/2);
half_seg = round(segment_time*fs/2);
seg_start = max(1, mid_sample-half_seg);
seg_end = min(N, mid_sample+half_seg);
t = (seg_start:seg_end)/fs;
figure('Name', 'ICA Track Separation', 'Position', [100, 100, 1200, 800]);

subplot(2,3,1);
plot(t, audio1(seg_start:seg_end), 'b'); hold on;
plot(t, audio2(seg_start:seg_end), 'r'); hold off;
title('Original Audio Tracks'); legend('Track 1','Track 2'); xlabel('Time (s)'); ylabel('Amplitude'); grid on;

subplot(2,3,2);
plot(t, mix1(seg_start:seg_end), 'k'); hold on;
plot(t, mix2(seg_start:seg_end), 'g'); hold off;
title('Mixed Tracks'); legend('Mix 1','Mix 2'); xlabel('Time (s)'); ylabel('Amplitude'); grid on;

subplot(2,3,3);
plot(t, sep1(seg_start:seg_end), 'b'); hold on;
plot(t, sep2(seg_start:seg_end), 'r'); hold off;
title('ICA Separated Tracks'); legend('Sep 1','Sep 2'); xlabel('Time (s)'); ylabel('Amplitude'); grid on;

% x-y plots for original, mixed, and separated tracks
subplot(2,3,4);
plot(audio1(seg_start:seg_end), audio2(seg_start:seg_end), 'k.');
title('Original: x vs y'); xlabel('Track 1'); ylabel('Track 2'); grid on;

subplot(2,3,5);
plot(mix1(seg_start:seg_end), mix2(seg_start:seg_end), 'g.');
title('Mixed: x vs y'); xlabel('Mix 1'); ylabel('Mix 2'); grid on;

subplot(2,3,6);
plot(sep1(seg_start:seg_end), sep2(seg_start:seg_end), 'r.');
title('ICA Separated: x vs y'); xlabel('Sep 1'); ylabel('Sep 2'); grid on;

fprintf('\nICA track separation complete!\n');
fprintf('Combined and separated files saved in outputs folder.\n');
