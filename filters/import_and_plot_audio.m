% import_and_plot_audio.m
% Import audio file and plot the original waveform
% This script demonstrates basic audio import and visualization

% Import audio file
[file, path] = uigetfile({'*.wav'}, 'Select an audio file for LPC pitch estimation');
if isequal(file,0)
    disp('No file selected. Exiting script.');
    return; % Exit if no file is selected
end
audio_filepath = fullfile(path, file);

try
    [audio, fs] = audioread(audio_filepath);
catch ME
    fprintf('Error loading audio file: %s\n', ME.message);
    return;
end

% If stereo, convert to mono
if size(audio, 2) > 1
    audio = mean(audio, 2);
end

% Create time vector
t = (0:length(audio)-1)/fs;

% Plot original waveform
figure('Name', 'Original Audio Waveform');
subplot(2,1,1);
plot(t, audio);
xlabel('Time (s)');
ylabel('Amplitude');
title('Original Audio Waveform');
grid on;

% Plot frequency spectrum
N = length(audio);
f = (0:N-1)*(fs/N);
Y = abs(fft(audio));

subplot(2,1,2);
plot(f(1:N/2), Y(1:N/2));
xlabel('Frequency (Hz)');
ylabel('Magnitude');
title('Original Audio Spectrum');
grid on;
xlim([0 2000]);

% Save as WAV file for further processing
audiowrite('../Samples/original_audio.wav', audio, fs);

fprintf('Audio imported successfully!\n');
fprintf('Sample Rate: %d Hz\n', fs);
fprintf('Duration: %.2f seconds\n', length(audio)/fs);
fprintf('Audio saved as original_audio.wav\n');
