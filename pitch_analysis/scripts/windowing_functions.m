% windowing_functions.m
% Compare different windowing functions in time and frequency domains

% Parameters
N = 512;  % Window length
fs = 1000; % Sampling frequency (Hz)

% Create different window functions
windows = struct();
windows.rectangular = ones(N, 1);
windows.hann = hann(N);
windows.hamming = hamming(N);
windows.blackman = blackman(N);
windows.kaiser = kaiser(N, 8.6);  % Beta = 8.6
windows.bartlett = bartlett(N);
windows.tukey = tukeywin(N, 0.5);  % 50% cosine taper

% Window names for plotting
window_names = {'Rectangular', 'Hann', 'Hamming', 'Blackman', 'Kaiser (β=8.6)', 'Bartlett', 'Tukey (α=0.5)'};
window_fields = fieldnames(windows);

% Create time vector
t = (0:N-1) / fs;

% Setup figure for time domain plots
figure('Position', [100, 100, 1400, 800]);

% Plot time domain
subplot(2, 1, 1);
colors = lines(length(window_fields));
hold on;
for i = 1:length(window_fields)
    plot(t, windows.(window_fields{i}), 'Color', colors(i,:), 'LineWidth', 2);
end
xlabel('Time (s)');
ylabel('Amplitude');
title('Window Functions - Time Domain');
legend(window_names, 'Location', 'best');
grid on;
xlim([0, max(t)]);

% Calculate and plot frequency domain
subplot(2, 1, 2);
NFFT = 2048;  % FFT length for better frequency resolution
f = (0:NFFT/2) * fs / NFFT;

hold on;
for i = 1:length(window_fields)
    % Zero-pad window for FFT
    w_padded = [windows.(window_fields{i}); zeros(NFFT - N, 1)];
    
    % Compute FFT
    W = fft(w_padded);
    W_mag = 20 * log10(abs(W(1:NFFT/2+1)) + eps);  % Convert to dB
    
    % Normalize to 0 dB peak
    W_mag = W_mag - max(W_mag);
    
    plot(f, W_mag, 'Color', colors(i,:), 'LineWidth', 2);
end

xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title('Window Functions - Frequency Domain (Magnitude Response)');
legend(window_names, 'Location', 'best');
grid on;
xlim([0, fs/2]);
ylim([-120, 5]);

% Save first figure with meaningful name
output_dir = '../outputs';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end
saveas(gcf, fullfile(output_dir, 'windowing_functions_comparison.png'));
fprintf('Figure saved as: windowing_functions_comparison.png\n');

% Create detailed comparison figure
figure('Position', [200, 200, 1400, 1000]);

% Calculate window properties
window_properties = table();
for i = 1:length(window_fields)
    w = windows.(window_fields{i});
    
    % Time domain properties
    coherent_gain = sum(w) / N;
    processing_gain = sum(w.^2) / N;
    scalloping_loss = -20*log10(abs(sum(w .* exp(-1j*pi*(0:N-1)'/N)))) + 20*log10(abs(sum(w)));
    
    % Frequency domain properties (using high-resolution FFT)
    w_padded = [w; zeros(NFFT - N, 1)];
    W = fft(w_padded);
    W_mag_linear = abs(W(1:NFFT/2+1));
    W_mag_linear = W_mag_linear / max(W_mag_linear);  % Normalize
    
    % Find main lobe width (3dB points)
    W_dB = 20*log10(W_mag_linear + eps);
    peak_idx = find(W_mag_linear == max(W_mag_linear), 1);
    
    % Find 3dB points
    left_3db = find(W_dB(1:peak_idx) <= -3, 1, 'last');
    right_3db = find(W_dB(peak_idx:end) <= -3, 1, 'first') + peak_idx - 1;
    
    if isempty(left_3db), left_3db = 1; end
    if isempty(right_3db), right_3db = length(W_dB); end
    
    main_lobe_width = f(right_3db) - f(left_3db);
    
    % Find highest side lobe
    side_lobe_mask = true(size(W_dB));
    side_lobe_mask(max(1,left_3db):min(length(W_dB),right_3db)) = false;
    if any(side_lobe_mask)
        highest_side_lobe = max(W_dB(side_lobe_mask));
    else
        highest_side_lobe = -Inf;
    end
    
    % Store properties
    window_properties.Window{i} = window_names{i};
    window_properties.CoherentGain(i) = coherent_gain;
    window_properties.ProcessingGain(i) = processing_gain;
    window_properties.ScallopingLoss_dB(i) = scalloping_loss;
    window_properties.MainLobeWidth_Hz(i) = main_lobe_width;
    window_properties.HighestSideLobe_dB(i) = highest_side_lobe;
end

% Plot individual windows with their properties
for i = 1:length(window_fields)
    subplot(ceil(length(window_fields)/2), 4, 2*i-1);
    plot(t, windows.(window_fields{i}), 'Color', colors(i,:), 'LineWidth', 2);
    xlabel('Time (s)');
    ylabel('Amplitude');
    title(sprintf('%s Window', window_names{i}));
    grid on;
    
    subplot(ceil(length(window_fields)/2), 4, 2*i);
    w_padded = [windows.(window_fields{i}); zeros(NFFT - N, 1)];
    W = fft(w_padded);
    W_mag = 20 * log10(abs(W(1:NFFT/2+1)) + eps);
    W_mag = W_mag - max(W_mag);
    
    plot(f, W_mag, 'Color', colors(i,:), 'LineWidth', 2);
    xlabel('Frequency (Hz)');
    ylabel('Magnitude (dB)');
    title(sprintf('%s - Frequency Response', window_names{i}));
    grid on;
    xlim([0, fs/2]);
    ylim([-120, 5]);
end

% Display properties table
fprintf('\n=== Window Function Properties ===\n');
disp(window_properties);

% Save second figure with meaningful name
saveas(gcf, fullfile(output_dir, 'windowing_functions_detailed.png'));
fprintf('Figure saved as: windowing_functions_detailed.png\n');

% Additional analysis: Effect on a test signal
figure('Position', [300, 300, 1200, 800]);

% Create a test signal with two close frequencies
f1 = 100; % Hz
f2 = 120; % Hz
t_test = (0:N-1) / fs;
test_signal = sin(2*pi*f1*t_test') + 0.5*sin(2*pi*f2*t_test');

% Apply different windows to test signal and show FFT
for i = 1:min(4, length(window_fields))  % Show first 4 windows
    subplot(2, 2, i);
    
    windowed_signal = test_signal .* windows.(window_fields{i});
    
    % Compute FFT
    Y = fft(windowed_signal, NFFT);
    Y_mag = 20*log10(abs(Y(1:NFFT/2+1)) + eps);
    
    plot(f, Y_mag, 'LineWidth', 2);
    xlabel('Frequency (Hz)');
    ylabel('Magnitude (dB)');
    title(sprintf('FFT with %s Window\n(Two tones: %d Hz & %d Hz)', window_names{i}, f1, f2));
    grid on;
    xlim([50, 200]);
    
    % Mark the true frequencies
    hold on;
    plot([f1 f1], ylim, 'r--', 'LineWidth', 1);
    plot([f2 f2], ylim, 'r--', 'LineWidth', 1);
    hold off;
end

sgtitle('Effect of Different Windows on Spectral Analysis');

% Save third figure with meaningful name
saveas(gcf, fullfile(output_dir, 'windowing_functions_test_signal.png'));
fprintf('Figure saved as: windowing_functions_test_signal.png\n');

fprintf('\nAnalysis complete! Three figures created:\n');
fprintf('1. Overall comparison of all windows (time & frequency)\n');
fprintf('2. Individual detailed plots for each window\n');
fprintf('3. Effect on spectral analysis of a two-tone test signal\n');
