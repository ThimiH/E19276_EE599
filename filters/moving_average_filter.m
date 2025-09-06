% moving_average_filter.m
% Moving Average Filter Implementation
% Simple FIR filter for smoothing signals

% Import audio file
[file, path] = uigetfile({'*.wav'; '*.mp3'}, 'Select an audio file for moving average filtering');
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

% Moving average filter parameters
windowSizes = [5, 10, 20, 50];  % Different window sizes to compare
colors = {'r', 'g', 'm', 'c'};

% Create figure for comparison
figure('Name', 'Moving Average Filter Analysis', 'Position', [100, 100, 1200, 800]);

% Use 2s to 2.1s segment for detailed view
start_time = 2.0;
end_time = 2.1;
start_sample = max(1, round(start_time * fs) + 1);
end_sample = min(length(audio), round(end_time * fs));
time_segment = start_sample:end_sample;

subplot(2,2,1);
if end_sample <= length(audio)
    t = (0:length(audio)-1)/fs;
    t_segment = t(time_segment);
    audio_segment = audio(time_segment);
    
    plot(t_segment, audio_segment, 'b', 'LineWidth', 1.5);
    hold on;
    
    % Apply different moving average filters
    for i = 1:length(windowSizes)
        windowSize = windowSizes(i);
        b = (1/windowSize) * ones(1, windowSize);  % MA filter coefficients
        a = 1;
        
        % Filter the full audio then extract segment
        filtered_audio_temp = filter(b, a, audio);
        filtered_segment = filtered_audio_temp(time_segment);
        plot(t_segment, filtered_segment, colors{i}, 'LineWidth', 1);
    end
    
    xlabel('Time (s)');
    ylabel('Amplitude');
    title('Moving Average Filter Comparison (2.0s to 2.1s)');
    legend(['Original', arrayfun(@(x) sprintf('MA-%d', x), windowSizes, 'UniformOutput', false)], ...
           'Location', 'best');
    grid on;
    xlim([start_time end_time]);
    hold off;
else
    text(0.5, 0.5, 'Audio too short for 2s-2.1s segment', ...
         'HorizontalAlignment', 'center', 'FontSize', 12);
    title('Audio Segment Not Available');
    xlabel('Time (s)');
    ylabel('Amplitude');
end

% Frequency responses of different MA filters
subplot(2,2,2);
w = linspace(0, pi, 2048);  % Higher resolution
for i = 1:length(windowSizes)
    windowSize = windowSizes(i);
    b = (1/windowSize) * ones(1, windowSize);
    H = freqz(b, 1, w);
    plot(w*fs/(2*pi), 20*log10(abs(H)), colors{i}, 'LineWidth', 1.5);
    hold on;
end
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title('MA Filter Frequency Responses');
legend(arrayfun(@(x) sprintf('MA-%d', x), windowSizes, 'UniformOutput', false), ...
       'Location', 'best');
grid on;
xlim([0 fs/2]);
ylim([-60 5]);
hold off;

% Apply MA filter to full audio (using window size 10)
windowSize = 10;
b = (1/windowSize) * ones(1, windowSize);
a = 1;
filtered_audio = filter(b, a, audio);

% Spectrum comparison (using 2s to 2.1s segment)
N_fft = 2048;
f = (0:N_fft/2-1)*(fs/N_fft);

% Use the same time segment for frequency analysis
if end_sample <= length(audio) && end_sample <= length(filtered_audio)
    audio_seg = audio(time_segment);
    filtered_seg = filtered_audio(time_segment);
    
    % Pad or truncate to N_fft length
    if length(audio_seg) < N_fft
        audio_seg = [audio_seg; zeros(N_fft - length(audio_seg), 1)];
        filtered_seg = [filtered_seg; zeros(N_fft - length(filtered_seg), 1)];
    else
        audio_seg = audio_seg(1:N_fft);
        filtered_seg = filtered_seg(1:N_fft);
    end
    
    Y_orig = abs(fft(audio_seg, N_fft));
    Y_filt = abs(fft(filtered_seg, N_fft));
else
    Y_orig = abs(fft(audio, N_fft));
    Y_filt = abs(fft(filtered_audio, N_fft));
end

subplot(2,2,3);
plot(f, 20*log10(Y_orig(1:N_fft/2)), 'b', 'LineWidth', 1.5);
hold on;
plot(f, 20*log10(Y_filt(1:N_fft/2)), 'r', 'LineWidth', 1.5);
hold off;
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title(sprintf('Spectrum: Original vs MA-%d Filtered (2.0s to 2.1s)', windowSize));
legend('Original', 'MA Filtered', 'Location', 'best');
grid on;
xlim([0 8000]);
ylim([-60 60]);

% Impulse response of MA filter
subplot(2,2,4);
impulse = [1; zeros(99, 1)];
impulse_response = filter(b, a, impulse);
stem(0:length(impulse_response)-1, impulse_response, 'filled', 'LineWidth', 1.5);
xlabel('Sample');
ylabel('Amplitude');
title(sprintf('MA-%d Filter Impulse Response', windowSize));
grid on;

% Save filtered audio
output_dir = '../samples/';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end
audiowrite([output_dir 'moving_average_output.wav'], filtered_audio, fs);

fprintf('\nMoving Average filter applied successfully!\n');
fprintf('Window size used: %d samples\n', windowSize);
fprintf('Sampling frequency: %d Hz\n', fs);
fprintf('Filtered audio saved as moving_average_output.wav in samples folder\n');
