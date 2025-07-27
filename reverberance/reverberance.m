% Read Audio from explorer
audio_file = '../Samples/Gajaman-Nona-Yohani-Ft-Tehan-Perera-www.song.lk.mp3';
[song, fs] = audioread(audio_file);

% Convert to mono if stereo for processing, but keep original for stereo processing
original_song = song;
is_stereo = size(song, 2) > 1;

if is_stereo
    song_mono = mean(song, 2);  % Mono version for processing
else
    song_mono = song;
    song = [song, song];  % Create stereo version for consistent processing
    is_stereo = false;
end

% Get smaller cut of 20 seconds for processing
song_mono = song_mono(1:min(20*fs, length(song_mono)), :);
if is_stereo
    original_song = original_song(1:min(20*fs, length(original_song)), :);
else
    original_song = original_song(1:min(20*fs, length(original_song)), 1);  % Keep mono for consistency
end

%% Reverberation Parameters
% Room characteristics
room_size = 0.7;           % Room size factor (0-1): 0=small room, 1=large hall
pre_delay = 0.03;          % Pre-delay in seconds (typical: 0.01-0.1s)
decay_time = 2.5;          % RT60 decay time in seconds (typical: 0.5-8s)
damping = 0.3;             % High frequency damping (0-1): 0=no damping, 1=heavy damping
wet_level = 0.4;           % Wet signal level (0-1)
dry_level = 0.6;           % Dry signal level (0-1)

% Frequency response parameters
low_tone = 0.7;            % Low frequency emphasis (0-1): 0=cut bass, 1=boost bass
high_tone = 0.5;           % High frequency emphasis (0-1): 0=cut treble, 1=boost treble

% Stereo parameters
stereo_width = 0.8;        % Stereo width (0-1): 0=mono, 1=full stereo width
enable_stereo = true;      % Enable stereo processing

% Reverberation control
reverberation = 0.6;       % Overall reverberation amount (0-1): 0=no reverb, 1=full reverb

% Early reflections parameters
num_early_reflections = 8;
early_reflection_gain = 0.6;

%% Generate Impulse Response for Reverberation

% Calculate delay times based on room size
max_delay = room_size * 0.2;  % Maximum delay in seconds
pre_delay_samples = round(pre_delay * fs);

% Generate early reflections
early_delays = sort(rand(num_early_reflections, 1) * max_delay * 0.3);
early_gains = early_reflection_gain * (0.5 + 0.5 * rand(num_early_reflections, 1)) * reverberation;
early_gains = early_gains .* exp(-early_delays * 2); % Exponential decay

% Generate late reverberation using feedback delay network
num_delays = 8;
delay_times = [0.030, 0.034, 0.039, 0.045, 0.050, 0.055, 0.062, 0.068]; % in seconds
delay_times = delay_times * (0.5 + room_size);  % Scale with room size

% Convert to samples
delay_samples = round(delay_times * fs);
max_samples = max([delay_samples, round(early_delays * fs)']);

% Create impulse response
impulse_length = round(decay_time * fs);
impulse_response = zeros(impulse_length, 1);

% Add direct signal at the beginning (this should be minimal for reverb-only)
% The main signal path should be the dry signal, not through the impulse response
impulse_response(1) = 0.001;  % Very small direct path

% Add pre-delay - this is when reflections start
if pre_delay_samples > 0 && pre_delay_samples < impulse_length
    % First significant reflection starts at pre_delay
    impulse_response(pre_delay_samples) = 0.1;
end

% Add early reflections
for i = 1:num_early_reflections
    delay_idx = round(early_delays(i) * fs) + pre_delay_samples;
    if delay_idx > 0 && delay_idx <= impulse_length
        impulse_response(delay_idx) = impulse_response(delay_idx) + early_gains(i);
    end
end

% Generate late reverberation using a simple exponential decay model
late_start = round(0.08 * fs);  % Late reverberation starts after 80ms
if late_start < impulse_length
    time_vector = (late_start:impulse_length-1)' / fs;
    
    % Create dense late reverberation
    noise_density = randn(length(time_vector), 1);
    
    % Apply exponential decay
    decay_envelope = exp(-time_vector * 6.91 / decay_time);  % -60dB at decay_time
    
    % Apply frequency-dependent damping
    if damping > 0
        % Simple high-frequency damping simulation
        for i = 2:length(noise_density)
            noise_density(i) = noise_density(i) * (1 - damping) + ...
                               noise_density(i-1) * damping * 0.3;
        end
    end
    
    % Combine with decay envelope and reverberation control
    late_reverb = noise_density .* decay_envelope * 0.1 * reverberation;
    
    % Add to impulse response
    impulse_response(late_start+1:end) = impulse_response(late_start+1:end) + late_reverb;
end

%% Apply Reverberation to Audio

% Normalize impulse response
impulse_response = impulse_response / max(abs(impulse_response));

% Apply convolution for reverberation
fprintf('Applying reverberation... This may take a moment.\n');
reverb_signal = conv(song_mono, impulse_response, 'full');

% Trim the reverb signal to match original length and ensure proper timing
reverb_signal = reverb_signal(1:length(song_mono));

% Normalize to prevent clipping
reverb_signal = reverb_signal / max(abs(reverb_signal));

%% Apply Frequency Filtering (Low Tone and High Tone)

% Design filters for tone control
nyquist = fs / 2;
low_cutoff = 200;   % Low frequency cutoff (Hz)
high_cutoff = 3000; % High frequency cutoff (Hz)

% Low tone filter (affects bass frequencies)
if low_tone ~= 0.5  % Only apply if different from neutral
    [b_low, a_low] = butter(2, low_cutoff/nyquist, 'low');
    low_filtered = filter(b_low, a_low, reverb_signal);
    
    % Mix with original based on low_tone parameter
    low_mix = (low_tone - 0.5) * 2;  % Convert to -1 to 1 range
    if low_mix > 0
        reverb_signal = reverb_signal + low_mix * low_filtered * 0.3;
    else
        reverb_signal = reverb_signal + low_mix * low_filtered * 0.3;
    end
end

% High tone filter (affects treble frequencies)
if high_tone ~= 0.5  % Only apply if different from neutral
    [b_high, a_high] = butter(2, high_cutoff/nyquist, 'high');
    high_filtered = filter(b_high, a_high, reverb_signal);
    
    % Mix with original based on high_tone parameter
    high_mix = (high_tone - 0.5) * 2;  % Convert to -1 to 1 range
    if high_mix > 0
        reverb_signal = reverb_signal + high_mix * high_filtered * 0.3;
    else
        reverb_signal = reverb_signal - abs(high_mix) * high_filtered * 0.3;
    end
    
    % Ensure no clipping
    reverb_signal = reverb_signal / max(abs(reverb_signal));
end

%% Create Stereo Reverb Signal

if enable_stereo && (is_stereo || stereo_width > 0)
    % Create stereo reverb with different delays for left and right channels
    delay_diff = round(0.001 * fs);  % 1ms delay difference
    
    % Left channel reverb
    reverb_left = reverb_signal;
    
    % Right channel reverb with slight delay and different characteristics
    reverb_right = [zeros(delay_diff, 1); reverb_signal(1:end-delay_diff)];
    
    % Apply stereo width
    mid_signal = (reverb_left + reverb_right) / 2;
    side_signal = (reverb_left - reverb_right) / 2;
    
    % Adjust stereo width
    side_signal = side_signal * stereo_width;
    
    % Reconstruct left and right channels
    reverb_left = mid_signal + side_signal;
    reverb_right = mid_signal - side_signal;
    
    % Combine into stereo reverb signal
    stereo_reverb = [reverb_left, reverb_right];
else
    % Mono reverb - duplicate to both channels
    stereo_reverb = [reverb_signal, reverb_signal];
end

%% Mix Dry and Wet Signals

% Ensure dry signal is stereo
if is_stereo
    dry_signal = original_song;
else
    dry_signal = [song_mono, song_mono];
end

% Apply wet/dry mix
output_signal = dry_level * dry_signal + wet_level * stereo_reverb;

% Normalize final output
max_val = max(max(abs(output_signal)));
output_signal = output_signal / max_val * 0.95;

%% Display Results and Analysis

figure('Position', [100, 100, 1200, 800]);

% Plot original signal
subplot(3, 2, 1);
if is_stereo
    time_orig = (0:length(original_song)-1) / fs;
    plot(time_orig, original_song(:,1), 'b-', time_orig, original_song(:,2), 'r-');
    legend('Left', 'Right', 'Location', 'best');
    title('Original Audio Signal (Stereo)');
else
    time_orig = (0:length(song_mono)-1) / fs;
    plot(time_orig, song_mono);
    title('Original Audio Signal (Mono)');
end
xlabel('Time (s)');
ylabel('Amplitude');
grid on;

% Plot impulse response
subplot(3, 2, 2);
time_impulse = (0:length(impulse_response)-1) / fs;
plot(time_impulse, impulse_response);
title(['Impulse Response (Room Size: ', num2str(room_size), ')']);
xlabel('Time (s)');
ylabel('Amplitude');
grid on;

% Plot reverb signal
subplot(3, 2, 3);
time_reverb = (0:length(stereo_reverb)-1) / fs;
if enable_stereo
    plot(time_reverb, stereo_reverb(:,1), 'b-', time_reverb, stereo_reverb(:,2), 'r-');
    legend('Left', 'Right', 'Location', 'best');
    title('Reverberated Signal (Stereo Wet Only)');
else
    plot(time_reverb, stereo_reverb(:,1));
    title('Reverberated Signal (Wet Only)');
end
xlabel('Time (s)');
ylabel('Amplitude');
grid on;

% Plot final output
subplot(3, 2, 4);
time_output = (0:length(output_signal)-1) / fs;
if size(output_signal, 2) > 1
    plot(time_output, output_signal(:,1), 'b-', time_output, output_signal(:,2), 'r-');
    legend('Left', 'Right', 'Location', 'best');
    title('Final Output (Stereo Dry + Wet Mix)');
else
    plot(time_output, output_signal);
    title('Final Output (Dry + Wet Mix)');
end
xlabel('Time (s)');
ylabel('Amplitude');
grid on;

% Frequency domain analysis
subplot(3, 2, 5);
if is_stereo
    [freq_orig, f_orig] = pwelch(original_song(:,1), [], [], [], fs);
    [freq_output, f_output] = pwelch(output_signal(:,1), [], [], [], fs);
else
    [freq_orig, f_orig] = pwelch(song_mono, [], [], [], fs);
    [freq_output, f_output] = pwelch(output_signal(:,1), [], [], [], fs);
end
semilogx(f_orig, 10*log10(freq_orig), 'b-', 'LineWidth', 1.5);
hold on;
semilogx(f_output, 10*log10(freq_output), 'r-', 'LineWidth', 1.5);
title('Frequency Response Comparison');
xlabel('Frequency (Hz)');
ylabel('Power (dB)');
legend('Original', 'With Reverb', 'Location', 'best');
grid on;

% Parameters display
subplot(3, 2, 6);
axis off;
param_text = {
    'Reverberation Parameters:';
    ['Room Size: ', num2str(room_size)];
    ['Pre-delay: ', num2str(pre_delay*1000), ' ms'];
    ['Decay Time (RT60): ', num2str(decay_time), ' s'];
    ['Damping: ', num2str(damping)];
    ['Wet Level: ', num2str(wet_level)];
    ['Dry Level: ', num2str(dry_level)];
    ['Early Reflections: ', num2str(num_early_reflections)];
    '';
    'Tone Control:';
    ['Low Tone: ', num2str(low_tone)];
    ['High Tone: ', num2str(high_tone)];
    '';
    'Stereo Processing:';
    ['Stereo Width: ', num2str(stereo_width)];
    ['Stereo Enabled: ', num2str(enable_stereo)];
    '';
    'Reverberation Control:';
    ['Reverberation: ', num2str(reverberation)];
    '';
    'Output Statistics:';
    ['Original RMS: ', num2str(rms(song_mono), '%.4f')];
    ['Output RMS: ', num2str(rms(output_signal(:,1)), '%.4f')];
    ['Dynamic Range: ', num2str(20*log10(max(max(abs(output_signal)))/rms(output_signal(:,1))), '%.1f'), ' dB'];
};
text(0.1, 0.9, param_text, 'FontSize', 10, 'VerticalAlignment', 'top', ...
     'FontName', 'Courier New');

sgtitle('Audio Reverberation Analysis', 'FontSize', 16, 'FontWeight', 'bold');

%% Audio Playback Options

fprintf('\nReverberation processing complete!\n');
fprintf('Parameters used:\n');
fprintf('  Room Size: %.2f\n', room_size);
fprintf('  Pre-delay: %.0f ms\n', pre_delay*1000);
fprintf('  Decay Time: %.1f s\n', decay_time);
fprintf('  Damping: %.2f\n', damping);
fprintf('  Wet/Dry Mix: %.1f/%.1f\n', wet_level, dry_level);
fprintf('  Low Tone: %.2f\n', low_tone);
fprintf('  High Tone: %.2f\n', high_tone);
fprintf('  Stereo Width: %.2f\n', stereo_width);
fprintf('  Reverberation: %.2f\n', reverberation);

% Audio playback with stop functionality
fprintf('\nPress Enter to play original audio...\n');
pause;
sound(song, fs);
fprintf('Press Enter to stop original audio and continue...\n');
pause;
clear sound;  % Stop any currently playing audio

fprintf('\nPress Enter to play reverberated audio...\n');
pause;
sound(output_signal, fs);
fprintf('Press Enter to stop reverberated audio and continue...\n');
pause;
clear sound;  % Stop any currently playing audio

%% Save Output (Optional)

% Uncomment to save the processed audio
output_filename = 'reverberated_audio.wav';
audiowrite(output_filename, output_signal, fs);
fprintf('Reverberated audio saved as: %s\n', output_filename);

%% Function to modify parameters and reprocess
fprintf('\nTo modify parameters, change the values in the "Reverberation Parameters" section and run again.\n');
fprintf('Key parameters to experiment with:\n');
fprintf('  - room_size (0-1): Controls overall spaciousness\n');
fprintf('  - pre_delay (0.01-0.1): Initial delay before reflections\n');
fprintf('  - decay_time (0.5-8): How long the reverb lasts\n');
fprintf('  - damping (0-1): High frequency absorption\n');
fprintf('  - wet_level/dry_level: Mix balance\n');