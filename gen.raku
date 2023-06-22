my $content = slurp "glfw3.h";

my $outf = open "GL.rakumod", :w;

my Str $header = "unit module GL;\nuse NativeCall;\n\n";

my Str $constant-enum = "enum GLFW (";
my Str $binding-str = "\n\n";
my Bool $enum-start = True;

my %types = 
    "int" => "int32", 
    "char*" => "Str", 
    "int*" => "int32 is rw", 
    "char**" => "CArray[Str]", 
    "float" => "num32",
    "uint32_t*" => "uint32",
    "void*" => "Pointer is rw",
    "double" => "num64",
    "PFN_vkGetInstanceProcAddr" => "", # don't know how to handle it yet,
    "GLFWerrorfun" => "Pointer is rw"
;

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
    $declaration ~~ s/^ \s* unsigned \s* //;

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

sub get-argument-str(Str $arg) returns Str {
    if %types{$arg}:exists {
        return %types{$arg};
    }

    if $arg.ends-with("*") {
        return "Pointer is rw";
    }

    if $arg.contains("void") {
        return "";
    }

    return "";
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
        my Str $name = $func.function_name;
        say $func;
        my $return_type-k = get-argument-str($func.return_type).words[0];
        my Str $return_type = "is native\(\"glfw_glad_all\"\) \{ * \}";
        if defined($return_type-k) {
            $return_type = "$return_type-k";
            if not $return_type.trim.chars == 0 {
                $return_type = "returns $return_type is native\(\"glfw_glad_all\"\) \{ * \}";
            }
        }
        
        my $func-str = "our sub $name";
        if $func.defined {
            my Str $types-str = "";
            for $func.argument_types -> $arg {
                next if $arg.contains("void;");

                my Str $type-str = get-argument-str($arg);
                if $types-str.trim.chars == 0 {
                    $types-str = "$type-str";
                } else {
                    $types-str = "$types-str, $type-str";
                }
                
            }
            $func-str = "$func-str\($types-str\) $return_type";
            $binding-str = "$binding-str\n$func-str";
        }
    }
}

$constant-enum = "$constant-enum \n);";

$outf.say($header);
$outf.say($constant-enum);
$outf.say($binding-str);
$outf.close;
