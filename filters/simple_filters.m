% Load an audio track
[file, path] = uigetfile({'*.wav;*.mp3'}, 'Select an audio file');
if isequal(file,0)
    error('No file selected.');
end
[audio, fs] = audioread(fullfile(path, file));

% Crop first 20 seconds
N = min(length(audio), 20*fs);
audio_crop = audio(1:N);

% Ensure mono for simplicity
if size(audio_crop,2) > 1
    audio_crop = mean(audio_crop,2);
end

% Apply (x[n]+x[n-1])/2 (simple moving average filter)
x1 = [audio_crop(1); audio_crop(1:end-1)];
avg_signal = (audio_crop + x1)/2;

% Apply (x[n]-x[n-1])/2 (simple difference filter)
diff_signal = (audio_crop - x1)/2;

% Plot signals
t = (0:N-1)/fs;
figure;
subplot(3,1,1);
plot(t, audio_crop);
title('Original Signal');
xlabel('Time (s)');
ylabel('Amplitude');

subplot(3,1,2);
plot(t, avg_signal);
title('Averaged Signal: (x[n]+x[n-1])/2');
xlabel('Time (s)');
ylabel('Amplitude');

subplot(3,1,3);
plot(t, diff_signal);
title('Differenced Signal: (x[n]-x[n-1])/2');
xlabel('Time (s)');
ylabel('Amplitude');

% Play signals
disp('Playing original signal...');
sound(audio_crop, fs);
pause(21);

disp('Playing averaged signal...');
sound(avg_signal, fs);
pause(21);

disp('Playing differenced signal...');
sound(diff_signal, fs);
pause(21);

% Save filtered signals as WAV files
[~, filename, ~] = fileparts(file);
output_dir = fullfile(path, 'filtered_outputs');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% Save averaged signal
avg_filename = fullfile(output_dir, [filename '_averaged.wav']);
audiowrite(avg_filename, avg_signal, fs);
disp(['Saved averaged signal as: ' avg_filename]);

% Save differenced signal
diff_filename = fullfile(output_dir, [filename '_differenced.wav']);
audiowrite(diff_filename, diff_signal, fs);
disp(['Saved differenced signal as: ' diff_filename]);

% Save original cropped signal for reference
orig_filename = fullfile(output_dir, [filename '_original_20s.wav']);
audiowrite(orig_filename, audio_crop, fs);
disp(['Saved original 20s signal as: ' orig_filename]);