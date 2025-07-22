% Load an audio file and plot its scalogram using MATLAB

% Select and read audio file
[file, path] = uigetfile({'*.wav;*.mp3','Audio Files (*.wav, *.mp3)'}, 'Select an audio file');
if isequal(file,0)
    disp('No file selected.');
    return;
end
[audioIn, fs] = audioread(fullfile(path, file));

% If stereo, convert to mono
if size(audioIn,2) > 1
    audioIn = mean(audioIn,2);
end

% Plot time-frequency analysis (substitute for cwt)
figure;

% Method 1: Using spectrogram (STFT-based approach)
window_size = 2048*4;
overlap = round(window_size * 0.75);
nfft = 2048*4;

[S, F, T] = spectrogram(audioIn, window_size, overlap, nfft, fs);
imagesc(T, F/1000, 20*log10(abs(S) + eps));
axis xy;
colorbar;
colormap('jet');
ylabel('Frequency (kHz)');
xlabel('Time (s)');
title(sprintf('Time-Frequency Analysis of %s', file));
ylim([0 1]); % Limit to 1 kHz for better visualization

% Save figure with meaningful name
[~, filename_only, ~] = fileparts(file);
output_dir = '../outputs';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end
saveas(gcf, fullfile(output_dir, sprintf('scalogram_analysis_%s.png', filename_only)));
fprintf('Figure saved as: scalogram_analysis_%s.png\n', filename_only);

% Alternative Method 2: Simple multi-scale analysis (uncomment to use)
% % Create frequency bands (scales)
% freqs = logspace(log10(50), log10(fs/2), 50); % 50 frequency bands from 50 Hz to Nyquist
% time_samples = length(audioIn);
% time_vector = (0:time_samples-1)/fs;
% 
% % Initialize result matrix
% scalogram = zeros(length(freqs), time_samples);
% 
% % Apply bandpass filtering at different frequencies
% for i = 1:length(freqs)
%     if i == 1
%         % Low-pass for first band
%         [b, a] = butter(4, freqs(i)/(fs/2), 'low');
%     elseif i == length(freqs)
%         % High-pass for last band
%         [b, a] = butter(4, freqs(i-1)/(fs/2), 'high');
%     else
%         % Band-pass for middle bands
%         [b, a] = butter(4, [freqs(i-1) freqs(i)]/(fs/2), 'bandpass');
%     end
%     
%     try
%         filtered = filtfilt(b, a, audioIn);
%         scalogram(i, :) = abs(hilbert(filtered)).^2; % Energy envelope
%     catch
%         scalogram(i, :) = zeros(1, time_samples);
%     end
% end
% 
% % Plot the scalogram
% figure;
% imagesc(time_vector, freqs, 10*log10(scalogram + eps));
% axis xy;
% colorbar;
% colormap('jet');
% ylabel('Frequency (Hz)');
% xlabel('Time (s)');
% title(['Multi-scale Analysis of ', file]);