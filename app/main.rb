require 'lib/zif/services/tick_trace_service.rb'
$trace_service = Zif::TickTraceService.new(10)
$trace_service.reset_tick

require 'lib/xy_pair_math.rb'
require 'lib/patches.rb'
require 'lib/utils.rb'

# @param [GTK::Args] args
# @return [Object, nil]
def tick(args)
  unless args.state.model
    # Load from an arbitrary `.off` file.
    args.state.model = Object3D.new({path: 'data/lowpoly_f117.off'})
    # Holds the current orientation of the model
    args.state.orient_mtx = rotate3D(0.00, 0.00, 0.00)
    # Holds the inverse of the current orientation of the model
    args.state.inv_orient_mtx = rotate3D(0.00, 0.00, 0.00)
    # Rotations to apply when certain buttons are pressed
    args.state.ctrl_mtx = {
        d: rotate3D(0.00, 0.00, 0.01),
        a: rotate3D(0.00, 0.00, -0.01),
        e: rotate3D(0.00, 0.02, 0.00),
        q: rotate3D(0.00, -0.02, 0.00),
        w: rotate3D(0.01, 0.00, 0.00),
        s: rotate3D(-0.01, 0.00, 0.00),
    }
    # Draw everything 4 times, for thicker lines
    args.outputs.static_lines << args.state.model.edges.map(&:dupe_off)
  end
  # Black backgrounds look cooler
  args.outputs.background_color = [0, 0, 0]

  # See if we need to rotate.
  rot_flag = false
  [:d, :a, :w, :s, :q, :e].each do |key|
    rot_flag |= args.inputs.keyboard.key_held.send(key)
  end

  if rot_flag
    # Update the orientation matrix
    [:d, :a, :w, :s, :q, :e].each do |key|
      next unless args.inputs.keyboard.key_held.send(key)
      args.state.orient_mtx = MatrixMath::dot(args.state.orient_mtx, args.state.ctrl_mtx[key])
    end
    # Calculate the delta rotation matrix of the model by multiplying the updated orientation mtx by its non-updated inverse
    rot = MatrixMath::dot(args.state.orient_mtx, args.state.inv_orient_mtx)
    # Update the inverse orientation matrix
    [:d, :a, :w, :s, :q, :e].each do |key|
      next unless args.inputs.keyboard.key_held.send(key)
      args.state.inv_orient_mtx = MatrixMath::dot(args.state.ctrl_mtx[key].transpose, args.state.inv_orient_mtx)
    end
    # Rotate the model
    args.state.model.fast_3x3_transform!(rot)
    # Sort the lines by z index so we get proper z-buffering. TODO: do this in a less dumb way.
    args.outputs.static_lines.sort!
  end
  args.outputs.debug << args.gtk.framerate_diagnostics_primitives
end

module MatrixMath
  # @param [Array<Array<Float>>] a
  # @param [Array<Array<Float>>] b
  # @return [Array<Array<Float>>]
  def MatrixMath::dot(a, b)
    is = (0...a.length)
    js = (0...b[0].length)
    ks = (0...b.length)
    is.map do |i|
      js.map do |j|
        sum = 0
        ks.each do |k|
          sum += a[i][k] * b[k][j]
        end
        sum
      end
    end
  end
end

# @param [Float] theta_x
# @param [Float] theta_y
# @param [Float] theta_z
# @return [Array<Array<Float>>]
def rotate3D(theta_x = 0.1, theta_y = 0.1, theta_z = 0.1)
  c_x, s_x = Math.cos(theta_x), Math.sin(theta_x)
  c_y, s_y = Math.cos(theta_y), Math.sin(theta_y)
  c_z, s_z = Math.cos(theta_z), Math.sin(theta_z)
  rot_x    = [
      [1, 0, 0],
      [0, c_x, -s_x],
      [0, s_x, c_x],
  ]
  rot_y    = [
      [c_y, 0, s_y],
      [0, 1, 0],
      [-s_y, 0, c_y],
  ]
  rot_z    = [
      [c_z, -s_z, 0],
      [s_z, c_z, 0],
      [0, 0, 1],
  ]
  MatrixMath.dot(MatrixMath.dot(rot_x, rot_y), rot_z)
end

class Vertex

  attr_accessor :x, :y, :z
  attr_accessor :id
  # @param [Array<String>] data
  # @param [Integer] id
  # @return [Vertex]
  def initialize(data, id)
    @x  = data[0].to_f
    @y  = data[1].to_f
    @z  = data[2].to_f
    @id = id
    self
  end

  def fast_3x3_transform!(mtx)
    @x, @y, @z = mtx[0][0] * @x + mtx[0][1] * @y + mtx[0][2] * @z, mtx[1][0] * @x + mtx[1][1] * @y + mtx[1][2] * @z, mtx[2][0] * @x + mtx[2][1] * @y + mtx[2][2] * @z
  end

  # @return [Array<Array<Float>>]
  def col_vector
    [
        [@x],
        [@y],
        [@z]
    ]
  end

  # @param [Array<Array<Float>>] col
  # @return [nil]
  def set_col_vector(col)
    @x = col[0][0]
    @y = col[1][0]
    @z = col[2][0]
  end

  # @return [Hash]
  def serialize
    {
        x:  @x,
        y:  @y,
        z:  @z,
        id: @id
    }
  end

  def inspect
    serialize.to_s
  end

  def to_s
    serialize.to_s
  end
end

class Face

  attr_reader :verts, :edges
  # @param [Array<String>] data
  # @param [Array<Vertex>] verts
  # @return [Face]
  def initialize(data, verts)
    vert_count = data[0].to_i
    vert_ids   = data[1, vert_count].map(&:to_i)
    @verts     = vert_ids.map { |i| verts[i] }
    # @type [Array<Edge>]
    @edges = []
    (0...vert_count).each { |i| @edges[i] = Edge.new(verts[vert_ids[i - 1]], verts[vert_ids[i]]) }
    @edges.rotate!(1)
    self
  end

  # @return [Hash]
  def serialize
    {
        verts: @verts,
        edges: @edges,
    }
  end

  # @return [String]
  def inspect
    serialize.to_s
  end

  # @return [String]
  def to_s
    serialize.to_s
  end
end

class Edge
  attr_accessor :r, :g, :b, :a
  attr_reader :point_a, :point_b
  # @param [Vertex] point_a
  # @param [Vertex] point_b
  # @return [Edge]
  def initialize(point_a, point_b, x_off = 0, y_off = 0)
    # @type [Vertex]
    @point_a = point_a
    # @type [Vertex]
    @point_b = point_b
    @a       = 255
    @r       = 255
    @g       = 0
    @b       = 0
    @x_off   = x_off
    @y_off   = y_off
  end

  # @return [Edge]
  def sorted
    @point_a.id < @point_b.id ? self : Edge.new(@point_b, @point_a)
  end

  def dupe_off
    [
        self,
        Edge.new(@point_a, @point_b, 0, 1),
        Edge.new(@point_a, @point_b, 1, 0),
        Edge.new(@point_a, @point_b, 1, 1),
    ]
  end

  # @return [Hash]
  def serialize
    {
        point_a: @point_a,
        point_b: @point_b,
    }
  end

  # @return [String]
  def inspect
    serialize.to_s
  end

  # @return [String]
  def to_s
    serialize.to_s
  end

  Scale = 150

  def x
    @point_a.x * (1 + 1 * (@point_a.y + 1)) * Edge::Scale + 640 + @x_off
  end

  def y
    @point_a.z * (1 + 1 * (@point_a.y + 1)) * Edge::Scale + 360 + @y_off
  end

  def x2
    @point_b.x * (1 + 1 * (@point_b.y + 1)) * Edge::Scale + 640 + @x_off
  end

  def y2
    @point_b.z * (1 + 1 * (@point_b.y + 1)) * Edge::Scale + 360 + @y_off
  end

  def g
    ((@point_a.y+@point_b.y)*0.25 + 0.5) * 255
  end

  def r
    255 - ((@point_a.y+@point_b.y)*0.25 + 0.5) * 255
  end

  def z
    (@point_a.y+@point_b.y) * 0.5
  end

  def <=> rhs
    z - rhs.z
  end

  def primitive_marker
    :line
  end
end

class Object3D
  # @!attribute [rw] verts
  #   @return [Array<Vertex>]
  attr_reader :vert_count, :face_count, :edge_count, :verts, :faces, :edges
  NewParameters = {
      path: 'data/model.off'
  }

  # @return [Object3D]
  # @param [Hash] parameters - Merged with Object3D::NewParameters
  def initialize(parameters = {})
    @vert_count = 0
    @face_count = 0
    @edge_count = 0
    # @type [Array<Vertex>]
    @verts = []
    @faces = []
    @edges = []

    params = Object3D::NewParameters.merge(parameters)
    _init_from_file(params[:path])
    self
  end

  # @param [String] path
  # @return [nil]
  def _init_from_file(path)
    # @type [Array<Array<String>>]
    file_lines = $gtk.read_file(path).split("\n")
                     .reject { |line| line.start_with?('#') || line.split(' ').length == 0 } # Strip out simple comments and blank lines
                     .map { |line| line.split('#')[0] } # Strip out end of line comments
                     .map { |line| line.split(' ') } # Tokenize by splitting on whitespace
    raise "OFF file did not start with OFF." if file_lines.shift != ["OFF"]
    raise "<NVertices NFaces NEdges> line malformed" if file_lines[0].length != 3
    @vert_count, @face_count, @edge_count = file_lines.shift&.map(&:to_i)
    raise "Incorrect number of vertices and/or faces (Parsed VFE header: #{@vert_count} #{@face_count} #{@edge_count})" if file_lines.length != @vert_count + @face_count
    vert_lines = file_lines[0, @vert_count]
    face_lines = file_lines[@vert_count, @face_count]
    @verts     = vert_lines.map_with_index { |line, id| Vertex.new(line, id) }
    # @type [Array<Face>]
    @faces = face_lines.map { |line| Face.new(line, @verts) }
    @edges = @faces.flat_map(&:edges).uniq do |edge|
      sorted = edge.sorted
      [sorted.point_a, sorted.point_b]
    end
  end

  # @param [Array<Array<Float>>] mtx
  # @return [nil]
  def fast_3x3_transform!(mtx)
    @verts.each { |vert| vert.fast_3x3_transform!(mtx) }
  end

  # @return [Hash]
  def serialize
    {
        vert_count: @vert_count,
        face_count: @face_count,
        edge_count: @edge_count,
        verts:      @verts,
        faces:      @faces,
        edges:      @edges,
    }
  end

  # @return [String]
  def inspect
    serialize.to_s
  end

  # @return [String]
  def to_s
    serialize.to_s
  end
end