my $content = slurp "glfw3.h";

my $outf = open "glfw_gl.raku", :w;

my Str $constant-enum = "enum GLFW (";
my Bool $enum-start = True;

sub remove_c_comments(Str $str) returns Str {
    my $comment_pattern = rx/ '/*' .*? '*/' /;
    my Str $st = $str.subst($comment_pattern, '', :g);
    return $st;
}

sub remove-appendix(Str $str) returns Str {
    return $str.subst(/^ 'GLFW_' /, '');
}

sub parse-constant(Str $constant-src) {
    return grep { $_ ne '' }, $constant-src.words;;
}

for $content.lines -> $line {

    if ($line.starts-with("#define ")) {
        my @res = parse-constant($line);
        my Str $name = remove-appendix(@res[1]);
        
        next if not defined(@res[2]) or not @res[2] ~~ /<digit>/;
        next if @res[2].index("GLFW").defined;

        my Str $val = @res[2];

        if ( $enum-start ) {
            $constant-enum = "$constant-enum\n    $name => $val";
            $enum-start = False;
        } else {
            $constant-enum = "$constant-enum,\n    $name => $val";
        }
    }
}

$constant-enum = "$constant-enum \n);";

$outf.say($constant-enum);
$outf.close;
