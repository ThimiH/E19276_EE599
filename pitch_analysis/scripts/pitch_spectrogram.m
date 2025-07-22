% --- 1. Load Audio File ---
[file, path] = uigetfile({'*.wav'}, 'Select an audio file for LPC pitch estimation');
if isequal(file,0)
    disp('No file selected. Exiting script.');
    return; % Exit if no file is selected
end
audio_filepath = fullfile(path, file);

try
    [x, fs] = audioread(audio_filepath);
catch ME
    fprintf('Error loading audio file: %s\n', ME.message);
    return;
end

% Convert to mono if stereo
if size(x,2) > 1
    x = mean(x,2);
    fprintf('Converted stereo audio to mono.\n');
end

% Plot spectrogram with higher frequency resolution and limit to 1 kHz
figure;
window_size = 4096*2;  % Larger window for better frequency resolution
overlap = 3072*2;      % 75% overlap
nfft = 4096*2;         % FFT size matches window size
spectrogram(x, window_size, overlap, nfft, fs, 'yaxis');
ylim([0 1]);         % Limit frequency display to 1 kHz
title(sprintf('Spectrogram (0-1 kHz, High Frequency Resolution) - %s', file));
xlabel('Time (s)');
ylabel('Frequency (kHz)');
colorbar;

% Save figure with meaningful name
[~, filename_only, ~] = fileparts(file);
output_dir = '../outputs';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end
saveas(gcf, fullfile(output_dir, sprintf('spectrogram_%s.png', filename_only)));
fprintf('Figure saved as: spectrogram_%s.png\n', filename_only);