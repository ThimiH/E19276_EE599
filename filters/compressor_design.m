% compressor_design.m
% Dynamic Range Compressor Implementation
% Controls dynamic range by reducing loud parts and boosting quiet parts

% Load audio
try
    [audio, fs] = audioread('../Samples/original_audio.wav');
catch
    [audio, fs] = audioread('../Samples/Gajaman-Nona-Yohani-Ft-Tehan-Perera-www.song.lk.mp3');
    if size(audio, 2) > 1
        audio = mean(audio, 2);
    end
end

% Compressor parameters
threshold_dB = -20;     % Threshold level (dB)
ratio = 4;              % Compression ratio (4:1)
attack_ms = 5;          % Attack time (ms)
release_ms = 100;       % Release time (ms)
makeup_gain_dB = 6;     % Makeup gain (dB)

% Convert to samples
attack_samples = round(attack_ms * fs / 1000);
release_samples = round(release_ms * fs / 1000);

% Convert threshold to linear
threshold_linear = 10^(threshold_dB/20);
makeup_gain = 10^(makeup_gain_dB/20);

% Initialize variables
N = length(audio);
compressed_audio = zeros(N, 1);
gain_reduction = zeros(N, 1);
envelope = zeros(N, 1);

% Attack and release coefficients
alpha_attack = exp(-1/attack_samples);
alpha_release = exp(-1/release_samples);

% Process audio sample by sample
for n = 1:N
    % Calculate envelope (peak detector)
    input_level = abs(audio(n));
    
    if n == 1
        envelope(n) = input_level;
    else
        if input_level > envelope(n-1)
            % Attack
            envelope(n) = alpha_attack * envelope(n-1) + (1-alpha_attack) * input_level;
        else
            % Release
            envelope(n) = alpha_release * envelope(n-1) + (1-alpha_release) * input_level;
        end
    end
    
    % Calculate gain reduction
    if envelope(n) > threshold_linear
        % Above threshold: apply compression
        excess_dB = 20*log10(envelope(n)) - threshold_dB;
        compressed_excess_dB = excess_dB / ratio;
        target_level_dB = threshold_dB + compressed_excess_dB;
        target_level_linear = 10^(target_level_dB/20);
        
        if envelope(n) > 0
            gain_reduction(n) = target_level_linear / envelope(n);
        else
            gain_reduction(n) = 1;
        end
    else
        % Below threshold: no compression
        gain_reduction(n) = 1;
    end
    
    % Apply gain reduction and makeup gain
    compressed_audio(n) = audio(n) * gain_reduction(n) * makeup_gain;
end

% Define segment for 2s to 2.1s
start_time = 2.0;
end_time = 2.1;
start_sample = max(1, round(start_time * fs) + 1);
end_sample = min(N, round(end_time * fs));
t_segment = (start_sample:end_sample)/fs;

% Create visualization
figure('Name', 'Dynamic Range Compressor Analysis');
tiledlayout(3,2, 'Padding', 'compact', 'TileSpacing', 'compact');
set(gcf, 'Position', [100, 100, 1200, 800]);

% Input vs Output levels (2s to 2.1s)
nexttile;
plot(t_segment, 20*log10(abs(audio(start_sample:end_sample))+eps), 'b', ...
     t_segment, 20*log10(abs(compressed_audio(start_sample:end_sample))+eps), 'r');
xlabel('Time (s)');
ylabel('Level (dB)');
title('Input vs Output Levels (2s to 2.1s)');
legend('Input', 'Compressed', 'Location', 'best');
grid on;
ylim([-60 0]);

% Gain reduction over time (2s to 2.1s)
nexttile;
plot(t_segment, 20*log10(gain_reduction(start_sample:end_sample)+eps));
xlabel('Time (s)');
ylabel('Gain Reduction (dB)');
title('Gain Reduction Over Time (2s to 2.1s)');
grid on;

% Compression characteristic curve (full range)
nexttile;
input_range_dB = -60:1:0;
input_range_linear = 10.^(input_range_dB/20);
output_range_dB = zeros(size(input_range_dB));
for i = 1:length(input_range_dB)
    if input_range_dB(i) > threshold_dB
        excess_dB = input_range_dB(i) - threshold_dB;
        compressed_excess_dB = excess_dB / ratio;
        output_range_dB(i) = threshold_dB + compressed_excess_dB + makeup_gain_dB;
    else
        output_range_dB(i) = input_range_dB(i) + makeup_gain_dB;
    end
end
plot(input_range_dB, output_range_dB, 'b', 'LineWidth', 2);
hold on;
plot(input_range_dB, input_range_dB, 'k--', 'LineWidth', 1);  % 1:1 line
line([threshold_dB threshold_dB], [-60 0], 'Color', 'r', 'LineStyle', '--');
xlabel('Input Level (dB)');
ylabel('Output Level (dB)');
title(sprintf('Compression Curve (Ratio %.0f:1)', ratio));
legend('Compressed', 'No Compression', 'Threshold', 'Location', 'northwest');
grid on;
% axis equal; % Removed for better scaling
xlim([-60 0]);
ylim([-60 20]);
hold off;

% Envelope detection (2s to 2.1s)
nexttile;
plot(t_segment, abs(audio(start_sample:end_sample)), 'b', ...
     t_segment, envelope(start_sample:end_sample), 'r', 'LineWidth', 2);
xlabel('Time (s)');
ylabel('Amplitude');
title('Envelope Detection (2s to 2.1s)');
legend('Input Signal', 'Detected Envelope', 'Location', 'best');
grid on;

% Spectrum comparison (full audio)
nexttile;
N_fft = 4096;
f = (0:N_fft/2-1)*(fs/N_fft);
Y_orig = abs(fft(audio, N_fft));
Y_comp = abs(fft(compressed_audio, N_fft));
semilogx(f(2:end), 20*log10(Y_orig(2:N_fft/2)), 'b', ...
         f(2:end), 20*log10(Y_comp(2:N_fft/2)), 'r');
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title('Spectrum: Before vs After Compression');
legend('Original', 'Compressed', 'Location', 'best');
grid on;
xlim([20 20000]);

% Dynamic range comparison (2s to 2.1s)
nexttile;
window_size = max(1, round(0.05 * fs));  % 50ms windows, smaller for short segment
step_size = max(1, round(0.025 * fs));   % 25ms steps
windows = start_sample:step_size:(end_sample-window_size);
rms_orig = zeros(length(windows), 1);
rms_comp = zeros(length(windows), 1);
if isempty(windows)
    % If segment is too short, plot single RMS value
    rms_orig_val = sqrt(mean(audio(start_sample:end_sample).^2));
    rms_comp_val = sqrt(mean(compressed_audio(start_sample:end_sample).^2));
    bar([1 2], [20*log10(rms_orig_val+eps), 20*log10(rms_comp_val+eps)]);
    set(gca, 'XTickLabel', {'Original', 'Compressed'});
    ylabel('RMS Level (dB)');
    title('RMS Levels Comparison (2s to 2.1s)');
    grid on;
else
    for i = 1:length(windows)
        start_idx = windows(i);
        end_idx = start_idx + window_size - 1;
        rms_orig(i) = sqrt(mean(audio(start_idx:end_idx).^2));
        rms_comp(i) = sqrt(mean(compressed_audio(start_idx:end_idx).^2));
    end
    t_windows = windows/fs;
    plot(t_windows, 20*log10(rms_orig+eps), 'b', ...
         t_windows, 20*log10(rms_comp+eps), 'r');
    xlabel('Time (s)');
    ylabel('RMS Level (dB)');
    title('RMS Levels Comparison (2s to 2.1s)');
    legend('Original', 'Compressed', 'Location', 'best');
    grid on;
end

% Calculate dynamic range
dr_orig = max(20*log10(rms_orig+eps)) - min(20*log10(rms_orig+eps));
dr_comp = max(20*log10(rms_comp+eps)) - min(20*log10(rms_comp+eps));

% Save compressed audio
compressed_audio_normalized = compressed_audio / max(abs(compressed_audio));
audiowrite('../Samples/compressed_audio.wav', compressed_audio_normalized, fs);

% Create a limiter example (high ratio compressor)
limiter_threshold_dB = -6;
limiter_ratio = 20;  % 20:1 ratio (effectively limiting)
limiter_threshold_linear = 10^(limiter_threshold_dB/20);

limited_audio = zeros(N, 1);
for n = 1:N
    input_level = abs(audio(n));
    
    if input_level > limiter_threshold_linear
        % Apply limiting
        limited_audio(n) = sign(audio(n)) * limiter_threshold_linear;
    else
        limited_audio(n) = audio(n);
    end
end

audiowrite('../Samples/limited_audio.wav', limited_audio/max(abs(limited_audio)), fs);

fprintf('Compressor analysis completed!\n');
fprintf('Compressor settings:\n');
fprintf('  Threshold: %.1f dB\n', threshold_dB);
fprintf('  Ratio: %.0f:1\n', ratio);
fprintf('  Attack: %.1f ms\n', attack_ms);
fprintf('  Release: %.1f ms\n', release_ms);
fprintf('  Makeup gain: %.1f dB\n', makeup_gain_dB);
fprintf('\nDynamic range reduction:\n');
fprintf('  Original: %.1f dB\n', dr_orig);
fprintf('  Compressed: %.1f dB\n', dr_comp);
fprintf('  Reduction: %.1f dB\n', dr_orig - dr_comp);
fprintf('\nAudio files saved:\n');
fprintf('- compressed_audio.wav\n');
fprintf('- limited_audio.wav\n');
