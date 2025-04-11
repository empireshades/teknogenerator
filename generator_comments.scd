(
// Array of rhythmic tags used to classify different beat patterns
var beat_tags = [\basebeat, \random, \offbeat, \break, \backbeat, \variation, \barline ];
// var harmony_tags = [\root, \variation, \drone]; // Commented out, not used

// Array of tags used to classify bar-level patterns
var bar_tags = [\all, \variation];

// Scaling factor for attention values
~attention_scale = 5;

// List of all available instruments in the system
~all_instruments = [\bd, \pads, \hat, \spectral_noise, \chords, \membrane, \hat909, \clap909, \fm_stab, \bell, \bass, \ride, \fm_stab, \sd, \clap ];

// Initialization function for the generation system
~init_generation = {
    // Load random hat sample from the hats directory
    p = ((File.getcwd.replace("\\", "/") ++ "/hats/hh*.wav").pathMatch ++
        (File.getcwd.replace("\\", "/") ++ "/hats/oh*.wav").pathMatch).choose;
    ~hats =  Buffer.read(s, p).normalize;

    // Load random clap sample from the claps directory
    p = (File.getcwd.replace("\\", "/") ++ "/claps/f9clp*.wav").pathMatch.choose;
    ~claps =  Buffer.read(s, p).normalize;

    // Define default attributes for each instrument
    // These serve as templates that will be modified when generating patterns
    ~default_attributes = (
        // Bass drum - low frequency percussion
        \bd: (\type: \rest, \sustain_time: 0.08.rrand(0.25), \amp: 1, \freq: 50.0.rrand(60.0), \release: 1.5.rrand(2.0), \distort: 0.0.rrand(0.6)),
        
        // Snare drum
        \sd: (\type: \rest, \amp: 0.4, \release: 0.02.rrand(0.2), \reverb: 0.001.exprand(0.05)),
        
        // Clap sound
        \clap: (\type: \rest, \amp: 0.7, \release: 0.05.exprand(0.15), \reverb: 0.1, \lfo: 10.0.rrand(60), \cutoff: 500.0.exprand(10e3)),
        
        // Hi-hat
        \hat: (\type: \rest, \amp: 0.5, \attack: 1e-3, \release: 0.02.rrand(0.05), \cutoff: 5e3.rrand(15e3), \reverb: 0.0.rrand(0.4)),
        
        // Spectral noise - textural sound
        \spectral_noise: (\type: \rest, \amp: 0.1, \cutoff: 1e3.rrand(1.5e3), \phase: 0.rrand(1), \teeth: 5.rrand(60), \rez: 0.5.rand(0.7)),
        
        // Ride cymbal
        \ride: (\type: \rest, \release: 2.0.rrand(5), \amp: 0.1),
        
        // Crash cymbal
        \cymbal: (\type: \rest, \release: 2.0.rrand(8.0), \amp: 0.1, \reverb: 0.001.exprand(0.05)),
        
        // Bass instrument
        \bass: (\type: \rest, \amp: 1, \freq: 50, \rez: 0.0.rrand(0.2), \filter_release: 0.01.exprand(1.0), \cutoff: 500.rrand(5e3), \legato: 4),
        
        // Chord instrument
        \chords: (\type: \rest, \freq: 440, \amp: 1, \sustain_time: 0.0.rrand(0.25), \filter_release: 0.02.rrand(0.1), \cutoff: 0.8e3.rrand(3e3), \env_type: 0, \reverb: 0.2),
        
        // FM synthesis stab sound
        \fm_stab: (\type: \rest, \freq: 100, \amp: 0.05, \attack: 1e-3, \release: 0.08.rrand(0.3), \detune: 0.5),
        
        // Bell-like sound
        \bell: (\type: \rest, \freq: 200.0.exprand(1200.0), \decay: 0.1.rrand(0.9), \amp: 0.1, \reverb: 0.0.rrand(0.7), \delay: 0.0.rrand(0.7)),
        
        // 909 style hi-hat (sample-based)
        \hat909: (\type: \rest, \amp: 0.01, \sustain_time: 0.05.rrand(0.2), \distort: 0.0.rrand(0.6), \bufnum: ~hats.bufnum, \rate: 1),
        
        // 909 style clap (sample-based)
        \clap909: (\type: \rest, \amp: 0.01, \sustain_time: 0.1.rrand(0.5), \distort: 0.0.rrand(0.6), \bufnum: ~claps.bufnum, \rate: 1),
        
        // Pad sounds - sustained atmospheric sounds
        \pads: (\type: \rest, \freq: 440, \amp: 1, \sustain_time: 0.0.rrand(0.25)),
        
        // Membrane percussion
        \membrane: (\type: \rest, \freq: 200.rrand(1e3), \amp: 0.05)
    );

    // Default attention values for each instrument
    // These determine how prominent each instrument should be in the mix
    ~default_attention = (
        \bd: 0,          // Bass drum starts with zero attention but is modified later
        \sd: 4,          // Snare drum has medium attention
        \clap: [ 2, 5].choose,  // Clap has variable attention
        \hat: 2,         // Hi-hat has low attention
        \ride: [2,7].choose,   // Ride cymbal has variable attention
        \cymbal: 7,      // Cymbal has high attention
        \bass: 3,        // Bass has medium attention
        \chords: [1,4].choose, // Chords have variable attention
        \fm_stab: [3, 10].choose, // FM stab has variable attention
        \bell: [2,5,10].choose,  // Bell has variable attention
        \clap909: 2,     // 909 clap has low attention
        \hat909: 2,      // 909 hat has low attention
        \pads: 2,        // Pads have low attention
        \membrane: 2,    // Membrane percussion has low attention
        \spectral_noise: 2  // Spectral noise has low attention
    );

    // Normalize attention values based on the maximum attention value
    m = ~default_attention.values.asArray.maxItem/~attention_scale;
    ~default_attention.keysValuesChange({
        arg key , value;
        value/m;
    });

    // Define a root sequence for harmonic content
    // Starts with root note (0) and adds one random transposition
    ~root_seq = [ 0 ] ++ ({ -5.rrand(5) } ! 1);
    // ~scale_seq = { [Scale.minor, Scale.major].choose } ! ~root_seq.size;  // Commented out, not used
};

// Main generation function - creates musical events
~generate = {
    // Parameters for generation
    arg tempo = 127, scale, root = 60, res = 32, bars = 1;
    
    // Initialize variables for the generated event
    var beat_tag;
    var bar_tag = \whole;
    var instrument = ~all_instruments.choose;  // Randomly select an instrument
    var attributes = ~default_attributes[instrument].copy;  // Copy default attributes for this instrument
    var attention = ~default_attention[instrument].copy;  // Copy default attention for this instrument
    var index  = 0;  // Initial time index (will be updated based on beat tag)
    var sustained = false;  // Flag for sustained notes

    // BASS DRUM CONFIGURATION
    if (instrument == \bd, {
        // Choose between basic beat and variation, heavily weighted toward basic
        beat_tag = [\basebeat, \variation].wchoose([10,1].normalizeSum);
        attributes[\type] = \note;  // Make this event produce sound (not rest)
        attributes[\amp] = 1;  // Full amplitude
        
        // For variation beats, reduce amplitude and increase attention
        if(beat_tag == \variation, {
            attributes[\amp] = 0.4;
            attention = ~attention_scale * 4;
        });
    });

    // SNARE DRUM CONFIGURATION
    if (instrument == \sd, {
        beat_tag = \backbeat;  // Snare typically plays on backbeats (2 and 4)
        attention = attention * 0.5.rrand(1.5);  // Random scaling of attention
        attributes[\type] = \note;  // Make this event produce sound
        // Randomly vary parameters within a reasonable range
        attributes.keysValuesChange { |key, value| value * 0.75.rrand(1.25) };
        attributes[\amp] = 0.4;  // Set amplitude
    });

    // CLAP CONFIGURATION
    if (instrument == \clap, {
        beat_tag = \backbeat;  // Clap typically plays on backbeats
        attention = attention * 0.5.rrand(1.5);  // Random scaling of attention
        // Randomly vary parameters
        attributes.keysValuesChange { |key, value| value * 0.5.rrand(1.5) };
        attributes[\release] = attributes[\release] * 0.5.exprand(3.0);  // Vary release more dramatically
        attributes[\type] = \note;  // Make this event produce sound
        attributes[\amp] = 0.2;  // Set amplitude
    });

    // HI-HAT CONFIGURATION
    if (instrument == \hat, {
        // Choose between different rhythmic patterns for hi-hat
        beat_tag = [\offbeat, \random, \n16th].choose;
        bar_tag = [\whole, \variation].choose;  // Choose bar variation
        attention = attention * 0.5.rrand(1.5);  // Random scaling of attention
        attributes[\type] = \note;  // Make this event produce sound
        // Randomly vary parameters
        attributes.keysValuesChange { |key, value| value * 0.5.rrand(1.5) };
        attributes[\release] = attributes[\release] * 0.5.exprand(2);  // Vary release
        
        // For random beats, increase attention and decrease amplitude
        if (beat_tag == \random, {
            attention = attention * 8;
            attributes[\amp] = attributes[\amp] * 0.1;
        });
        
        // For 16th note beats, decrease amplitude and increase attention
        if (beat_tag == \n16th, {
            attributes[\amp] = attributes[\amp] * 0.2;
            attention = attention * 4;
        });
    });

    // SPECTRAL NOISE CONFIGURATION
    if (instrument == \spectral_noise, {
        beat_tag = \offbeat;  // Spectral noise plays on offbeats
        attention = 0;  // Set attention to 0 (will always be included)
        attributes[\type] = \note;  // Make this event produce sound
        attributes[\amp] = 0.2;  // Set amplitude
    });

    // CYMBAL CONFIGURATION
    if (instrument == \cymbal, {
        beat_tag = \offbeat;  // Cymbal plays on offbeats
        attention = attention * 0.5.rrand(1.5);  // Random scaling of attention
        attributes[\type] = \note;  // Make this event produce sound
        // Widely vary parameters
        attributes.keysValuesChange { |key, value| value * 0.2.rrand(1.8) };
        attributes[\amp] = 0.1;  // Set amplitude
    });

    // RIDE CYMBAL CONFIGURATION
    if (instrument == \ride, {
        beat_tag = \offbeat;  // Ride plays on offbeats
        attention = attention * 0.5.rrand(1.5);  // Random scaling of attention
        attributes[\type] = \note;  // Make this event produce sound
        // Widely vary parameters
        attributes.keysValuesChange { |key, value| value * 0.2.rrand(1.8) };
        attributes[\amp] = 0.1;  // Set amplitude
    });

    // 909 HI-HAT CONFIGURATION
    if (instrument == \hat909, {
        beat_tag = \offbeat;  // 909 hat plays on offbeats
        attributes[\type] = \note;  // Make this event produce sound
        attributes[\bufnum] = ~hats.bufnum;  // Set sample buffer
        attributes[\rate] = 0.98.rrand(1.02);  // Slightly vary playback rate
        
        // For random beats, increase attention
        if (beat_tag == \random, {
            attention = attention * 16;
        });
        
        // For 16th note beats, decrease amplitude and increase attention
        if (beat_tag == \n16th, {
            attributes[\amp] = attributes[\amp] * 0.4;
            attention = attention * 8;
        });
    });

    // 909 CLAP CONFIGURATION
    if (instrument == \clap909, {
        beat_tag = \backbeat;  // 909 clap plays on backbeats
        attention = attention * 0.5.rrand(1.5);  // Random scaling of attention
        attributes[\type] = \note;  // Make this event produce sound
        attributes[\amp] = 0.05 * 0.5.rrand(1.5);  // Set amplitude with variation
        attributes[\bufnum] = ~claps.bufnum;  // Set sample buffer
        attributes[\rate] = 0.98.rrand(1.02);  // Slightly vary playback rate
    });

    // BASS CONFIGURATION
    if (instrument == \bass, {
        var k = ~root_seq.choose;  // Choose a root note from the sequence
        beat_tag = [\offbeat, \variation].choose;  // Choose rhythmic pattern
        attributes[\type] = \note;  // Make this event produce sound
        attention = attention * 0.5.rrand(1.5);  // Random scaling of attention
        // Randomly vary parameters
        attributes.keysValuesChange { |key, value| value * 0.5.rrand(1.5) };
        // Set frequency based on scale and root note
        attributes[\freq] = Scale.minor.degreeToFreq(0, (root+k).midicps, -2);
        // Choose between different legato (note length) values
        attributes[\legato] = ({ arg i; 2**(i+1) } ! 2).choose;
        attributes[\cutoff] = 100.rrand(0.5e3);  // Set filter cutoff
        attributes[\amp] = 1;  // Set amplitude
        
        // Set bar tag based on whether we're using root note or variation
        bar_tag = \root;
        if (k != 0, {
            bar_tag = \variation;
        });

        // For variation beats, increase attention
        if (beat_tag == \variation, {
            attention = attention * 2;
        });
    });

    // CHORDS CONFIGURATION
    if (instrument == \chords, {
        var k, octave, freqs, amps;
        
        // Make this event produce sound
        attributes[\type] = \note;
        
        // Randomly vary parameters
        attributes.keysValuesChange { |key, value| value * 0.5.rrand(1.5) };
        
        // Set sustain time to a discrete rhythmic value
        attributes[\sustain_time] = 60/Tempo.bpm * [ 1/8, 1/4, 1/2 ].choose;
        
        // Choose between variation and backbeat patterns
        beat_tag = [\variation, \backbeat ].choose;
        
        // For variation beats, increase attention
        if (beat_tag == \variation, {
            attention = attention * 5;
        });
        
        // Choose a position in the root sequence
        k = ~root_seq.size.rand;
        octave = [0, 1].choose;  // Choose octave
        
        // Generate chord frequencies from the minor scale
        // Select even-numbered degrees (0, 2, 4, 6, 8, 10) up to a random limit
        freqs = (0, 2..[ 6, 8, 10].choose).collect {
            arg degree; Scale.minor.degreeToFreq(degree, (root + ~root_seq[k]).midicps, octave);
        };
        
        // Set amplitude per voice (quieter for more voices)
        amps = 0.5 / freqs.size;
        
        // Set bar tag based on whether we're using root note or variation
        bar_tag = \root;
        if (k != 0, {
            bar_tag = \variation;
        });
        
        // Set frequencies and amplitude
        attributes[\freq] = freqs;
        attributes[\amp] = amps;
    });

    // PADS CONFIGURATION
    if (instrument == \pads, {
        var n = 8;
        var k = ~root_seq.size.rand;  // Choose position in root sequence
        
        // Generate pad frequencies from minor scale
        var freqs = (0, 2..[4, 6, 8].choose).collect { 
            arg degree; Scale.minor.degreeToFreq(degree, (root + ~root_seq[k]).midicps, 0); 
        };
        
        // Set amplitude per voice
        var amps = 0.5 / n;

        // Set bar tag based on whether we're using root note or variation
        bar_tag = \root;
        if (k != 0, {
            bar_tag = \variation;
        });
        
        // Randomly vary parameters
        attributes.keysValuesChange { |key, value| value * 0.5.rrand(1.5) };
        
        // Set frequencies and amplitude
        attributes[\freq] = freqs;
        attributes[\amp] = amps;
        
        // Set long sustain time (4 bars)
        attributes[\sustain_time] = 60/Tempo.bpm * 4;
        
        // Pads typically play at bar lines
        beat_tag = \barline;
        
        // For variation beats, increase attention
        if (beat_tag == \variation, {
            attention = attention * 5;
        });
        
        // Make this event produce sound
        attributes[\type] = \note;
    });

    // FM STAB CONFIGURATION
    if (instrument == \fm_stab, {
        var k = ~root_seq.choose;  // Choose a root note from sequence
        
        // Choose between variation and backbeat patterns
        beat_tag = [\variation, \backbeat].choose;
        
        // Slightly vary attention
        attention = attention * 0.8.rrand(1.2);
        
        // Slightly vary parameters
        attributes.keysValuesChange { |key, value| value * 0.9.rrand(1.1) };
        
        // Make this event produce sound
        attributes[\type] = \note;
        
        // Set frequency based on scale, with random degree between -2 and 2
        attributes[\freq] = Scale.minor.degreeToFreq(-2.rrand(2), (root+k).midicps, -1);
        
        // Set bar tag based on whether we're using root note or variation
        bar_tag = \root;
        if (k != 0, {
            bar_tag = \variation;
        });
    });

    // BELL CONFIGURATION
    if (instrument == \bell, {
        // Choose between offbeat and variation patterns
        beat_tag = [\offbeat, \variation].choose;
        
        // Random scaling of attention
        attention = attention * 0.5.rrand(1.5);
        
        // Make this event produce sound
        attributes[\type] = \note;
        
        // Slightly vary parameters
        attributes.keysValuesChange { |key, value| value * 0.99.rrand(1.01) };
        
        // For variation beats, increase attention
        if (beat_tag == \variation, {
            attention = attention * 4;
        });
    });

    // MEMBRANE CONFIGURATION
    if (instrument == \membrane, {
        // Choose between offbeat and variation patterns
        beat_tag = [\offbeat, \variation].choose;
        
        // Random scaling of attention
        attention = attention * 0.5.rrand(1.5);
        
        // Make this event produce sound
        attributes[\type] = \note;
        
        // Slightly vary parameters
        attributes.keysValuesChange { |key, value| value * 0.99.rrand(1.01) };
        
        // For random beats, increase attention
        if (beat_tag == \random, {
            attention = attention * 4;
        });
        
        // For variation beats, decrease amplitude
        if (beat_tag == \variation, {
            attributes[\amp] = attributes[\amp] * 0.1;
        });
    });

    // BEAT POSITIONING LOGIC
    // This determines where in the timeline the event will be placed
    
    // Base beat - typically on quarters (1, 2, 3, 4)
    if (beat_tag == \basebeat, {
        index = (res*4.rand)/4;  // Random quarter note position
    });

    // Back beat - typically on 2 and 4
    if (beat_tag == \backbeat, {
        index = (res*2.rand/2) + (res/4);  // Random half note position offset by quarter
    });

    // Off beat - typically on the "and" counts
    if (beat_tag == \offbeat, {
        index = (res*4.rand/4) + (res/8);  // Random quarter note position offset by eighth
    });

    // 16th note position
    if (beat_tag == \n16th, {
        index = (res*8.rand/8) + (res/16);  // Random 8th note position offset by 16th
    });

    // Random position - anywhere in the bar
    if (beat_tag == \random, {
        index = res.rand;  // Completely random position
    });

    // Variation position - slightly offset from common positions
    if (beat_tag == \variation, {
        index = (res*7.rand/8) + [0, (res/8), (res/16)].choose;  // Random position with small offset
    });

    // Bar line position - at the start of a bar
    if (beat_tag == \barline, {
        index = 0;  // Beginning of bar
    });

    // BAR POSITIONING LOGIC
    // This adds an offset to place the event in a specific bar
    
    // Whole pattern - can appear in any bar
    if (bar_tag == \whole, {
        index = index + (res*bars.rand);  // Add offset for random bar
    });

    // Root pattern - appears in any bar except the last
    if (bar_tag == \root, {
        index = index + (res*(bars-1).rand);  // Add offset for random bar except last
    });

    // Variation pattern - appears in the last bar
    if (bar_tag == \variation, {
        index = index + (res*(bars-1));  // Add offset for last bar
    });

    // Return the generated event as a structured object
    (\instrument: instrument, \beat_tag: beat_tag, \sustained: sustained, \attention: attention, \attributes: attributes, \index: index)
};

// Swing function that adds human-like timing variations to the sequence
// Implemented as a ProtoEvent that can be chained with other patterns
~swingify = Prout({ |ev|
    var now, nextTime = 0, thisShouldSwing, nextShouldSwing = false, adjust;
    while { ev.notNil } {
        // Current time is what was "next" last time
        now = nextTime;
        nextTime = now + ev.delta;
        
        // Determine if this event should be swung
        thisShouldSwing = nextShouldSwing;
        
        // Determine if the next event should be swung
        // Events swing if they're close to a swing base boundary and on an odd boundary
        nextShouldSwing = ((nextTime absdif: nextTime.round(ev[\swingBase])) <= (ev[\swingThreshold] ? 0)) and: {
            (nextTime / ev[\swingBase]).round.asInteger.odd
        };
        
        // Calculate swing adjustment amount
        adjust = ev[\swingBase] * ev[\swingAmount];
        
        // Apply swing to current event
        if(thisShouldSwing) {
            // Delay this event by the swing amount
            ev[\timingOffset] = (ev[\timingOffset] ? 0) + adjust;
            
            // If next note will not swing, this note needs to be shortened
            if(nextShouldSwing.not) {
                ev[\sustain] = ev.use { ~sustain.value } - adjust;
            };
        } {
            // If next note will swing, this note needs to be lengthened
            if(nextShouldSwing) {
                ev[\sustain] = ev.use { ~sustain.value } + adjust;
            };
        };
        
        // Yield the modified event
        ev = ev.yield;
    };
});
)