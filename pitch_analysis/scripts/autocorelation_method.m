% autocorelation_method.m
% Thimira Hirushan
% Estimate pitch using autocorrelation method

% Load audio file
[file, path] = uigetfile({'*.wav'}, 'Select an audio file');
if isequal(file,0)
    error('No file selected.');
end
[audio, fs] = audioread(fullfile(path, file));

% Convert to mono if stereo
if size(audio,2) > 1
    audio = mean(audio,2);
end

% Skip first 1 second and then select a 0.03 second segment
skip_duration = 2.0; % seconds to skip
segment_duration = 2; % seconds
skip_samples = round(skip_duration * fs);
segment_samples = round(segment_duration * fs);
start_idx = skip_samples + 1;
end_idx = start_idx + segment_samples - 1;

% Ensure we don't exceed audio length
if end_idx > length(audio)
    error('Audio file is too short. Need at least %.2f seconds.', skip_duration + segment_duration);
end

x = audio(start_idx:end_idx);

% Remove DC offset
x = x - mean(x);

% Compute autocorrelation
r = xcorr(x, 'coeff');

% Only look at positive lags
mid = length(r)/2;
r_pos = r(mid:end);

% Find peak in autocorrelation (excluding lag 0)
[~, peak_lag] = max(r_pos(50:end));
pitch_period = peak_lag; % in samples

% Estimate pitch (Hz)
pitch_freq = fs / pitch_period;

% Display result
fprintf('Estimated pitch: %.2f Hz\n', pitch_freq);

% Optional: plot autocorrelation
figure;
lags = (0:length(r_pos)-1)/fs;
plot(lags, r_pos);
xlabel('Lag (seconds)');
ylabel('Autocorrelation');
title(sprintf('Autocorrelation of Audio Segment - %s', file));
grid on;

% Save figure with meaningful name
[~, filename_only, ~] = fileparts(file);
output_dir = '../outputs';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end
saveas(gcf, fullfile(output_dir, sprintf('autocorrelation_%s.png', filename_only)));
fprintf('Figure saved as: autocorrelation_%s.png\n', filename_only);