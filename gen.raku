my $content = slurp "glfw3.h";

my $outf = open "glfw_gl.raku", :w;

my Str $constant-enum = "enum GLFW (";
my Bool $enum-start = True;

class ParsedFunc {
    has Str $.return_type;
    has Str $.function_name;
    has Array $.argument_types;
}

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

sub parse-func(Str $func-src) returns ParsedFunc {
    my $declaration = "$func-src";
    $declaration ~~ s/^ \s* GLFWAPI \s* //;
    $declaration ~~ s/^ \s* const \s* //;

    my ($return_type, $rest) = $declaration.split(/\s+/, 2);
    my ($function_name, $arguments) = $rest.split(/\(/, 2);

    if $arguments {
        $arguments ~~ s/\)//;
        my @argument_types = $arguments.split(',')
            .map({ .trim.split(/\s+/).grep({ $_ ne 'const' }).join(' ') });
        
        @argument_types = @argument_types.map({ .words[0] });
        return ParsedFunc.new(return_type => $return_type, function_name => $function_name, argument_types => @argument_types);
    }
    else {
        say "Invalid function declaration";
        return Nil;
    }
}

for $content.lines -> $line {

    if $line.starts-with("#define ") {
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
    } elsif $line.starts-with("GLFWAPI") {
        my ParsedFunc $func = parse-func($line);
        if $func.defined {
            
        }
    }
}

$constant-enum = "$constant-enum \n);";

$outf.say($constant-enum);
$outf.close;
