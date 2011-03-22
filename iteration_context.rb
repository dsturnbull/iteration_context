# stick this in your spec helper
# then you can iterate over spec groups:
#
# IterationContext.list = ['v1.06', 'v1.07', 'v1.08']
#
# describe HappyTimes do
#   # all versions
#   context :all_versions do
#     it 'should test things'
#   end
# 
#   # a specific version
#   context 'v1.06' do
#     it 'should test things'
#   end
# 
#   # a list
#   context ['v1.06', 'v1.07'] do
#     it 'should test things'
#   end
# 
#   # a predicate
#   context :version >= 'v1.06' do
#     it 'should test things'
#   end
# 
#   # a range
#   context 'v1.06' .. 'v1.07' do
#     it 'should test things'
#   end
# end
#
# this produces:
#
# HappyTimes
#   :all_versions
#     v1.06
#       should test things (PENDING: Not Yet Implemented)
#     v1.07
#       should test things (PENDING: Not Yet Implemented)
#     v1.08
#       should test things (PENDING: Not Yet Implemented)
#   v1.06
#     should test things (PENDING: Not Yet Implemented)
#   ["v1.06", "v1.07"]
#     v1.06
#       should test things (PENDING: Not Yet Implemented)
#     v1.07
#       should test things (PENDING: Not Yet Implemented)
#   ":version >= v1.06"
#     v1.06
#       should test things (PENDING: Not Yet Implemented)
#     v1.07
#       should test things (PENDING: Not Yet Implemented)
#     v1.08
#       should test things (PENDING: Not Yet Implemented)
#   "v1.06".."v1.07"
#     v1.06
#       should test things (PENDING: Not Yet Implemented)
#     v1.07
#       should test things (PENDING: Not Yet Implemented)

class IterationContext
  def self.list
    @@list
  end

  def self.list=(l)
    @@list = l
  end
end

module SymbolPredicate
  def self.list=(l)
    @@list = l
  end

  def evaluate_version_predicate(op, n)
    versions = @@list.map do |v|
      a = v[1, v.length].to_f
      b = n[1, n.length].to_f
      code = "#{a} #{op} #{b}"
      v if eval(code)
    end
    ([op.to_sym, n] + versions).compact
  end

  def <(v)
    evaluate_version_predicate('<', v)
  end

  def >(v)
    evaluate_version_predicate('>', v)
  end

  def <=(v)
    evaluate_version_predicate('<=', v)
  end

  def >=(v)
    evaluate_version_predicate('>=', v)
  end
end
Symbol.send(:include, SymbolPredicate)

module RSpec
  module Core
    class Example
      attr_accessor :api_version

      def run_with_api_version(example_group_instance, reporter)
        ENV['API_VERSION'] = api_version
        run_without_api_version(example_group_instance, reporter)
      end
      alias_method_chain :run, :api_version
    end

    class ExampleGroup
      class << self
        def describe_with_versioning(*args, &block)
          versions = []

          if args.length == 1
            arg = args.first

            # specific version
            if arg.is_a?(String) && IterationContext.list.include?(arg)
              versions << arg

            # range of versions
            elsif arg.is_a?(Range)

              min_version = arg.first
              max_version = arg.last
              min_index = 0
              max_index = 0

              c = 0
              IterationContext.list.each_with_index do |version, i|
                min_index = i if version == min_version
                c += 1 if i >= min_index
                max_index = i
                break if version == max_version
              end

              versions += IterationContext.list[min_index, c]

            # all versions

            elsif arg.is_a?(Symbol) && arg == :all_versions
              versions += IterationContext.list

            # array of versions
            elsif arg.is_a?(Array)
              if arg.first.is_a?(Symbol)
                op1 = arg.shift
                op2 = arg.shift
                args[0] = ":version #{op1} #{op2}"
              end
              versions += arg
            end
          end

          # default to all versions
          if versions.length <= 1
            describe_without_versioning(*args, &block)
          else
            context args.first.inspect do
              versions.each do |version|
                example_group = describe_without_versioning([version], &block)
                example_group.examples.each do |example|
                  example.api_version = version
                end
              end
            end
          end
        end

        alias_method_chain :describe, :versioning
        alias :context :describe

      end
    end
  end
end

class Module
  def alias_method_chain( target, feature )
    alias_method "#{target}_without_#{feature}", target
    alias_method target, "#{target}_with_#{feature}"
  end
end

class Object
  alias :is_an? :is_a?
end
